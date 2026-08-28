(() => {
  const commandDepth = new Map([
    ['docker', 2],
    ['git', 1],
  ]);
  const commandWrappers = new Set([
    'command',
    'env',
    'exec',
    'nohup',
    'sudo',
    'time',
  ]);

  const tokenClass = {
    command: 'nf',
    comment: 'c1',
    keyword: 'k',
    number: 'm',
    operator: 'o',
    path: 's1',
    string: 's2',
    variable: 'nv',
  };

  function appendToken(fragment, text, type) {
    if (!text) return;
    if (!type) {
      fragment.append(document.createTextNode(text));
      return;
    }

    const span = document.createElement('span');
    span.className = tokenClass[type];
    span.textContent = text;
    fragment.append(span);
  }

  function highlightCommand(code) {
    if (code.dataset.cliHighlighted === 'true') return;

    const source = code.textContent;
    const fragment = document.createDocumentFragment();
    let command = '';
    let continuedLine = false;
    let expectCommand = true;
    let index = 0;
    let subcommandsLeft = 0;

    while (index < source.length) {
      const character = source[index];

      if (/\s/.test(character)) {
        const start = index;
        while (index < source.length && /\s/.test(source[index])) index += 1;
        const whitespace = source.slice(start, index);
        appendToken(fragment, whitespace);
        if (whitespace.includes('\n')) {
          expectCommand = !continuedLine;
          if (expectCommand) {
            command = '';
            subcommandsLeft = 0;
          }
          continuedLine = false;
        }
        continue;
      }

      if (
        character === '#' &&
        (index === 0 || /[\s;&|]/.test(source[index - 1]))
      ) {
        const end = source.indexOf('\n', index);
        const stop = end === -1 ? source.length : end;
        appendToken(fragment, source.slice(index, stop), 'comment');
        index = stop;
        continue;
      }

      if (character === "'" || character === '"') {
        const quote = character;
        const start = index;
        index += 1;
        while (index < source.length) {
          if (source[index] === '\\' && quote === '"') index += 2;
          else if (source[index++] === quote) break;
        }
        appendToken(fragment, source.slice(start, index), 'string');
        expectCommand = false;
        continue;
      }

      if (character === '$') {
        const variable = source
          .slice(index)
          .match(/^\$(?:\{[^}\n]+\}|[A-Za-z_][A-Za-z0-9_]*|[@*#?$!-])/);
        if (variable) {
          appendToken(fragment, variable[0], 'variable');
          index += variable[0].length;
          expectCommand = false;
          continue;
        }
      }

      if (character === '\\' && source[index + 1] === '\n') {
        appendToken(fragment, '\\', 'operator');
        index += 1;
        continuedLine = true;
        continue;
      }

      const operator = source.slice(index).match(/^(?:&&|\|\||>>|<<|[|;&<>])/);
      if (operator) {
        appendToken(fragment, operator[0], 'operator');
        index += operator[0].length;
        if (['&&', '||', '|', ';', '&'].includes(operator[0])) {
          command = '';
          expectCommand = true;
          subcommandsLeft = 0;
        }
        continue;
      }

      const option = source
        .slice(index)
        .match(/^(?:--|--?[A-Za-z0-9][A-Za-z0-9_-]*(?:=[^\s|;&<>]+)?)/);
      if (option) {
        appendToken(fragment, option[0], 'keyword');
        index += option[0].length;
        continue;
      }

      const start = index;
      while (index < source.length && !/[\s'"$|;&<>]/.test(source[index]))
        index += 1;
      if (start === index) {
        appendToken(fragment, character);
        index += 1;
        continue;
      }

      const word = source.slice(start, index);
      let type;
      if (expectCommand) {
        command = word.replace(/^.*\//, '');
        subcommandsLeft = commandDepth.get(command) || 0;
        type = 'command';
        expectCommand = commandWrappers.has(command);
      } else if (subcommandsLeft > 0 && /^[A-Za-z][A-Za-z0-9_-]*$/.test(word)) {
        type = 'keyword';
        subcommandsLeft -= 1;
      } else if (
        word === '.' ||
        word === '..' ||
        /^(?:\.?\.?\/|\/|~\/|https?:\/\/)/.test(word) ||
        word.includes('/')
      ) {
        type = 'path';
      } else if (/^\d+(?:\.\d+)*$/.test(word)) {
        type = 'number';
      }
      appendToken(fragment, word, type);
    }

    code.replaceChildren(fragment);
    code.dataset.cliHighlighted = 'true';
  }

  function setupSyntaxHighlighting() {
    document
      .querySelectorAll('.md-typeset .language-bash code')
      .forEach(highlightCommand);
  }

  if (typeof document$ !== 'undefined') {
    document$.subscribe(setupSyntaxHighlighting);
  } else if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupSyntaxHighlighting, {
      once: true,
    });
  } else {
    setupSyntaxHighlighting();
  }
})();
