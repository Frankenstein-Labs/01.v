import { s__ } from '~/locale';

export default {
  registries: {
    emptyStateTitle: s__('VirtualRegistry|There are no maven virtual registries yet'),
  },
  upstreams: {
    emptyStateTitle: s__('VirtualRegistry|Connect Maven virtual registry to an upstream'),
    emptyStateDescription: s__(
      'VirtualRegistry|Configure an upstream registry to manage Maven artifacts and cache entries.',
    ),
    deleteCacheModalTitle: s__('VirtualRegistry|Delete Maven upstream cache entry?'),
  },
  registryType: s__('VirtualRegistry|Maven'),
};
