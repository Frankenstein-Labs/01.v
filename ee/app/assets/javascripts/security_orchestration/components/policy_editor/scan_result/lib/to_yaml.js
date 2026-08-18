import { safeDump } from 'js-yaml';
import { removeIdsFromPolicy } from '../../utils';

/*
 Return yaml representation of a policy.
*/
export const policyToYaml = (policy) => {
  return safeDump(removeIdsFromPolicy(policy), { noRefs: true });
};
