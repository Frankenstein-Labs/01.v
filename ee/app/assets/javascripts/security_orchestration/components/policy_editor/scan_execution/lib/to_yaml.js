import { safeDump } from 'js-yaml';

export const toYaml = (yaml) => {
  return safeDump(yaml);
};
