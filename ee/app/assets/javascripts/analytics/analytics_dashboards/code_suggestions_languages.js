/* eslint-disable @gitlab/require-i18n-strings */

// List of supported Code Suggestions languages referenced from https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/blob/main/code_suggestions_config.json
// TODO: To be replaced with a GraphQL field in https://gitlab.com/gitlab-org/gitlab/-/issues/574170
export const SUPPORTED_LANGUAGES = [
  {
    languageId: 'c',
    humanReadableName: 'C',
    fileExtensions: ['.c'],
  },
  {
    languageId: 'cpp',
    humanReadableName: 'C++',
    fileExtensions: ['.cpp', '.cc', '.cxx', '.c++', '.h', '.hpp', '.hxx', '.h++'],
  },
  {
    languageId: 'csharp',
    humanReadableName: 'C#',
    fileExtensions: ['.cs'],
  },
  {
    languageId: 'go',
    humanReadableName: 'Go',
    fileExtensions: ['.go'],
  },
  {
    languageId: 'haml',
    humanReadableName: 'HAML',
    fileExtensions: ['.haml'],
  },
  {
    languageId: 'handlebars',
    humanReadableName: 'Handlebars',
    fileExtensions: ['.hbs', '.handlebars'],
  },
  {
    languageId: 'java',
    humanReadableName: 'Java',
    fileExtensions: ['.java'],
  },
  {
    languageId: 'javascript',
    humanReadableName: 'JavaScript',
    fileExtensions: ['.js'],
  },
  {
    languageId: 'javascriptreact',
    humanReadableName: 'JavaScript React',
    fileExtensions: ['.jsx'],
  },
  {
    languageId: 'kotlin',
    humanReadableName: 'Kotlin',
    fileExtensions: ['.kt', '.kts'],
  },
  {
    languageId: 'python',
    humanReadableName: 'Python',
    fileExtensions: ['.py'],
  },
  {
    languageId: 'php',
    humanReadableName: 'PHP',
    fileExtensions: ['.php'],
  },
  {
    languageId: 'ruby',
    humanReadableName: 'Ruby',
    fileExtensions: ['.rb'],
  },
  {
    languageId: 'rust',
    humanReadableName: 'Rust',
    fileExtensions: ['.rs'],
  },
  {
    languageId: 'scala',
    humanReadableName: 'Scala',
    fileExtensions: ['.scala'],
  },
  {
    languageId: 'shellscript',
    humanReadableName: 'Shell',
    fileExtensions: ['.sh'],
  },
  {
    languageId: 'sql',
    humanReadableName: 'SQL',
    fileExtensions: ['.sql'],
  },
  {
    languageId: 'swift',
    humanReadableName: 'Swift',
    fileExtensions: ['.swift'],
  },
  {
    languageId: 'typescript',
    humanReadableName: 'TypeScript',
    fileExtensions: ['.ts'],
  },
  {
    languageId: 'typescriptreact',
    humanReadableName: 'TypeScript React',
    fileExtensions: ['.tsx'],
  },
  {
    languageId: 'svelte',
    humanReadableName: 'Svelte',
    fileExtensions: ['.svelte'],
  },
  {
    languageId: 'terraform',
    humanReadableName: 'Terraform',
    fileExtensions: ['.tf', '.tfvars'],
  },
  {
    languageId: 'terragrunt',
    humanReadableName: 'Terragrunt',
    fileExtensions: ['.hcl'],
  },
  {
    languageId: 'vue',
    humanReadableName: 'Vue',
    fileExtensions: ['.vue'],
  },
];

export const getLanguageDisplayName = (languageId) => {
  if (!languageId) return null;

  const supportedLanguage = SUPPORTED_LANGUAGES.find(
    (language) =>
      language.languageId === languageId || language.fileExtensions.includes(`.${languageId}`),
  );

  return supportedLanguage?.humanReadableName ?? languageId;
};
