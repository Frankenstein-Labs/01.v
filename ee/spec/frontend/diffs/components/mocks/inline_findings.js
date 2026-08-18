export const codequalityData = {
  files: {
    'index.js': [
      {
        severity: 'minor',
        description: 'Unexpected alert.',
        line: 1,
      },
      {
        severity: 'major',
        description:
          'Function `aVeryLongFunction` has 52 lines of code (exceeds 25 allowed). Consider refactoring.',
        line: 3,
      },
      {
        severity: 'minor',
        description: 'Arrow function has too many statements (52). Maximum allowed is 30.',
        line: 3,
      },
    ],
  },
};

export const sastData = {
  added: [
    {
      description:
        'Second finding Markup escaping disabled. This can be used with some template engines to escape\ndisabling of HTML entities, which can lead to XSS attacks.\n',
      severity: 'low',
      location: {
        file: 'index.js',
        startLine: '1',
      },
      foundByPipelineIid: '2',
      state: 'DETECTED',
      identifiers: [
        {
          externalId: 'eslint.detect-disable-mustache-escape',
          externalType: 'semgrep_id',
          name: 'eslint.detect-disable-mustache-escape',
          url: 'https://semgrep.dev/r/gitlab.eslint.detect-disable-mustache-escape',
        },
      ],
      title: 'Improper Neutralization of Input During Web Page Generation (XSS)',
      details: [
        {
          name: 'code_flows',
          items: [],
        },
      ],
    },
    {
      description:
        'Second finding Markup escaping disabled. This can be used with some template engines to escape\ndisabling of HTML entities, which can lead to XSS attacks.\n',
      severity: 'medium',
      location: {
        file: 'index.js',
        startLine: '3',
      },
      foundByPipelineIid: '2',
      state: 'DETECTED',
      identifiers: [
        {
          externalId: 'eslint.detect-disable-mustache-escape',
          externalType: 'semgrep_id',
          name: 'eslint.detect-disable-mustache-escape',
          url: 'https://semgrep.dev/r/gitlab.eslint.detect-disable-mustache-escape',
        },
      ],
      title: 'Improper Neutralization of Input During Web Page Generation (XSS)',
    },
  ],
};
