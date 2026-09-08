from __future__ import annotations

import shutil
import subprocess
import unittest
from pathlib import Path
from shlex import quote
from tempfile import TemporaryDirectory
from typing import Final, final, override

TEMPLATE: Final = (
    Path(__file__).resolve().parents[2]
    / "config"
    / "bin"
    / "executable_open-url.tmpl"
)

# The handler only forwards its target, so these never touch the filesystem.
# They just have to look like a hyperlink a terminal would emit.
DIRECTORY: Final = "/Users/me/projects"
TARGET: Final = f"{DIRECTORY}/mise.toml"

# `#{client_activity} #{session_name}` lines, least recently active first.
CLIENTS: Final = ("10 detached", "20 active")

# Base-system utilities the handler pipes through. The sandbox PATH exposes
# these and nothing else, so a missing fake fails loudly instead of reaching
# the host - notably the real macOS `open`.
UTILITIES: Final = ("cut", "dirname", "head", "perl", "sed", "sort")

TIMEOUT: Final = 30

# Fakes report their own name and argv NUL-separated, so a test can assert the
# exact command line the handler built rather than a substring of it.
REPORT_ARGV: Final = "printf '%s\\000' {name} \"$@\"\n"

# `new-window` reports every argument except the pane command, then runs that
# command through a real shell. Whatever the pane process reports therefore
# went through the same two rounds of parsing as in production: once by this
# script, once by the session shell.
TMUX_FAKE: Final = """\
case $1 in
  list-clients)
    {clients}
    ;;
  new-window)
    printf '%s\\000' tmux
    while [ "$#" -gt 1 ]; do
      printf '%s\\000' "$1"
      shift
    done
    printf 'pane\\000'
    exec {pane_shell} -c "$1"
    ;;
  *)
    printf 'unexpected tmux argv: %s\\n' "$*" >&2
    exit 64
    ;;
esac
"""

MISE_FAKE: Final = """\
case "$*" in
  'which nvim') printf '%s\\n' {nvim} ;;
  *)
    printf 'unexpected mise argv: %s\\n' "$*" >&2
    exit 64
    ;;
esac
"""


def chezmoi_executable() -> str:
    """Locate chezmoi, which renders the template under test."""
    location = shutil.which("chezmoi")
    if location is None:
        raise RuntimeError("chezmoi must be on PATH; try `mise run test:unit`")
    return location


@final
class OpenUrlTest(unittest.TestCase):
    """Behavior of the rendered `config/bin/executable_open-url.tmpl`.

    Alacritty invokes this handler from a GUI, where a failure is silent and
    invisible. Every test therefore renders the real template with chezmoi and
    executes the result, asserting the exact process and argv it launches.
    """

    @override
    def setUp(self) -> None:
        temporary = TemporaryDirectory(prefix="open-url-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for directory in ("bin", "config", "cache", "data"):
            (self.root / directory).mkdir()
        for utility in UTILITIES:
            location = shutil.which(utility)
            if location is None:
                self.fail(f"the handler pipes through {utility}, not on PATH")
            (self.commands / utility).symlink_to(location)

    @property
    def commands(self) -> Path:
        """The sandbox PATH: fakes plus the real base-system utilities."""
        return self.root / "bin"

    @property
    def handler(self) -> Path:
        return self.root / "open-url"

    @property
    def environment(self) -> dict[str, str]:
        return {
            "HOME": str(self.root),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_CACHE_HOME": str(self.root / "cache"),
            "XDG_DATA_HOME": str(self.root / "data"),
            "PATH": str(self.commands),
        }

    def write_fake(self, name: str, body: str) -> None:
        executable = self.commands / name
        _ = executable.write_text(
            f"#!/bin/sh\nset -eu\n{body}", encoding="utf-8"
        )
        executable.chmod(0o700)

    def render(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                chezmoi_executable(),
                "--config",
                "/dev/null",
                "--config-format",
                "toml",
                "--source",
                str(self.root),
                "--destination",
                str(self.root),
                "execute-template",
            ],
            input=TEMPLATE.read_text(encoding="utf-8"),
            env=self.environment,
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
            timeout=TIMEOUT,
        )

    def build(
        self,
        *,
        clients: tuple[str, ...] = CLIENTS,
        pane_shell: str = "/bin/sh",
        opener: str = "open",
        resolves_nvim: bool = True,
        nvim_executable: bool = True,
    ) -> None:
        """Install the fakes, then render the template against them."""
        nvim = self.commands / "nvim"
        if nvim_executable:
            self.write_fake("nvim", REPORT_ARGV.format(name="nvim"))
        else:
            _ = nvim.write_text("#!/bin/sh\n", encoding="utf-8")
            nvim.chmod(0o600)
        self.write_fake(
            "mise",
            MISE_FAKE.format(nvim=quote(str(nvim)))
            if resolves_nvim
            else "exit 1\n",
        )
        reported = " ".join(quote(client) for client in clients)
        self.write_fake(
            "tmux",
            TMUX_FAKE.format(
                clients=f"printf '%s\\n' {reported}" if clients else "true",
                pane_shell=pane_shell,
            ),
        )
        self.write_fake(opener, REPORT_ARGV.format(name=opener))
        rendered = self.render()
        if rendered.returncode != 0:
            self.fail(f"chezmoi failed to render: {rendered.stderr}")
        _ = self.handler.write_text(rendered.stdout, encoding="utf-8")
        # chezmoi deploys this as `executable_`, so honor the shebang.
        self.handler.chmod(0o700)

    def run_handler(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(self.handler), *arguments],
            env=self.environment,
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
            timeout=TIMEOUT,
        )

    def launched(
        self, result: subprocess.CompletedProcess[str]
    ) -> tuple[tuple[str, ...], tuple[str, ...]]:
        """Split the reported argv at the `pane` sentinel tmux prints."""
        fields = result.stdout.split("\0")
        if fields and fields[-1] == "":
            _ = fields.pop()
        if "pane" not in fields:
            return tuple(fields), ()
        boundary = fields.index("pane")
        return tuple(fields[:boundary]), tuple(fields[boundary + 1 :])

    def assert_opens(
        self,
        result: subprocess.CompletedProcess[str],
        *,
        editor: tuple[str, ...],
        directory: str = DIRECTORY,
        session: str | None = "active",
    ) -> None:
        window = ("tmux", "new-window")
        if session is not None:
            window += ("-t", session)
        window += ("-n", "nvim", "-c", directory)
        self.assertEqual(
            (result.returncode, self.launched(result)),
            (0, (window, ("nvim", *editor))),
            f"stderr={result.stderr!r}",
        )

    def assert_failed(
        self, result: subprocess.CompletedProcess[str], status: int, reason: str
    ) -> None:
        self.assertEqual(result.returncode, status, f"stderr={result.stderr!r}")
        self.assertIn(reason, result.stderr)
        self.assertEqual(result.stdout, "", "nothing should have been launched")

    def pane_shells(self) -> tuple[tuple[str, str], ...]:
        """The shells that parse the pane command in production."""
        fish = shutil.which("fish")
        if fish is None:
            return (("sh", "/bin/sh"),)
        return (("sh", "/bin/sh"), ("fish", f"{quote(fish)} --no-config"))

    def test_reads_a_line_hint_without_mangling_the_path(self) -> None:
        for target, editor in (
            (f"{TARGET}:9", ("+9", "--", TARGET)),
            (TARGET, ("--", TARGET)),
            # A trailing colon group that is not a line number stays part of
            # the path, or the handler would open the wrong file.
            (f"{TARGET}:9x", ("--", f"{TARGET}:9x")),
            (f"{TARGET}:", ("--", f"{TARGET}:")),
            (f"file://{TARGET}", ("--", TARGET)),
            (f"file://{TARGET}#L9", ("+9", "--", TARGET)),
            # A range fragment jumps to where it starts.
            (f"file://{TARGET}#L15-L23", ("+15", "--", TARGET)),
            (f"file://{TARGET}#9", ("+9", "--", TARGET)),
            (f"file://{TARGET}#anchor", ("--", TARGET)),
            (f"file://localhost{TARGET}", ("--", TARGET)),
        ):
            with self.subTest(target=target):
                self.build()
                self.assert_opens(self.run_handler(target), editor=editor)

    def test_decoded_path_survives_the_pane_shell(self) -> None:
        # An apostrophe has to cross this script, tmux, and the session shell
        # intact; the template escapes it as POSIX '\'' for sh and fish alike.
        for name, pane_shell in self.pane_shells():
            with self.subTest(pane_shell=name):
                self.build(pane_shell=pane_shell)
                result = self.run_handler("file:///tmp/it's%20a%20file#L9")
                self.assert_opens(
                    result,
                    editor=("+9", "--", "/tmp/it's a file"),
                    directory="/tmp",
                )

    def test_decoded_leading_plus_is_not_an_ex_command(self) -> None:
        # Without the `--` terminator, nvim reads a leading `+` as an Ex
        # command, so file://%2B!id would run `id` through a shell.
        for name, pane_shell in self.pane_shells():
            with self.subTest(pane_shell=name):
                self.build(pane_shell=pane_shell)
                result = self.run_handler("file://%2B!id")
                self.assert_opens(result, editor=("--", "+!id"), directory=".")

    def test_targets_the_most_recently_active_client(self) -> None:
        # A session name may contain spaces, hence `cut -f 2-`.
        self.build(clients=("30 stale", "40 my session", "20 older"))
        self.assert_opens(
            self.run_handler(TARGET),
            editor=("--", TARGET),
            session="my session",
        )

    def test_omits_the_target_when_no_client_is_attached(self) -> None:
        # Clicking a link with tmux detached must still open the file.
        self.build(clients=())
        self.assert_opens(
            self.run_handler(TARGET), editor=("--", TARGET), session=None
        )

    def test_hands_an_external_url_to_the_system_opener(self) -> None:
        self.build()
        target = "https://example.test/a%20b#L9"
        result = self.run_handler(target)
        self.assertEqual(
            (result.returncode, result.stderr, self.launched(result)),
            (0, "", (("open", target), ())),
        )

    def test_falls_back_to_xdg_open_without_open(self) -> None:
        self.build(opener="xdg-open")
        target = "https://example.test/"
        result = self.run_handler(target)
        self.assertEqual(
            (result.returncode, result.stderr, self.launched(result)),
            (0, "", (("xdg-open", target), ())),
        )

    def test_reports_a_stale_baked_tmux_path(self) -> None:
        # Paths are baked at apply time; moving tmux must not fail silently,
        # which is the whole defect this handler exists to fix.
        self.build()
        (self.commands / "tmux").unlink()
        self.assert_failed(self.run_handler(TARGET), 1, "rerun chezmoi apply")

    def test_reports_a_stale_baked_mise_path(self) -> None:
        self.build()
        (self.commands / "mise").unlink()
        self.assert_failed(self.run_handler(TARGET), 1, "rerun chezmoi apply")

    def test_reports_when_mise_cannot_resolve_nvim(self) -> None:
        self.build(resolves_nvim=False)
        self.assert_failed(
            self.run_handler(TARGET), 1, "could not resolve an nvim"
        )

    def test_reports_when_the_resolved_nvim_is_not_executable(self) -> None:
        self.build(nvim_executable=False)
        self.assert_failed(
            self.run_handler(TARGET), 1, "which is not executable"
        )

    def test_requires_exactly_one_argument(self) -> None:
        self.build()
        for arguments in ((), (TARGET, TARGET)):
            with self.subTest(arguments=arguments):
                result = self.run_handler(*arguments)
                self.assert_failed(result, 2, "exactly one URL argument")
                self.assertIn("Usage:", result.stderr)

    def test_render_fails_when_tmux_is_missing_at_apply_time(self) -> None:
        # The template refuses to bake an empty path, so a bad `chezmoi apply`
        # is caught then rather than on the first click.
        self.write_fake("mise", "exit 0\n")
        rendered = self.render()
        self.assertNotEqual(rendered.returncode, 0)
        self.assertIn("tmux not found on PATH", rendered.stderr)


if __name__ == "__main__":
    _ = unittest.main()
