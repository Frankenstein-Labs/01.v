export const getSecurityTabPath = (pipelinePath = '') => `${pipelinePath}/security`;

export const latestNonClosedMergeRequest = (mergeRequests) =>
  (mergeRequests ?? []).filter((m) => m.state !== 'closed').at(-1);
