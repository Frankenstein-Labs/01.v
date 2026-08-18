import { s__ } from '~/locale';

export default {
  registries: {
    emptyStateTitle: s__('VirtualRegistry|There are no container virtual registries yet'),
    pageHeading: s__('VirtualRegistry|Container virtual registries'),
  },
  upstreams: {
    emptyStateTitle: s__('VirtualRegistry|Connect Container virtual registry to an upstream'),
    emptyStateDescription: s__(
      'VirtualRegistry|Configure an upstream registry to manage Container artifacts and cache entries.',
    ),
    deleteCacheModalTitle: s__('VirtualRegistry|Delete Container upstream cache entry?'),
  },
  newRegistryPageTitle: s__('VirtualRegistry|New container virtual registry'),
  registryType: s__('VirtualRegistry|Container'),
  editRegistryPageTitle: s__('VirtualRegistry|Edit container virtual registry'),
};
