import { TYPENAME_ARTIFACT_REGISTRY_REPOSITORY, TYPENAME_ORGANIZATION } from '../../constants';

// Evicts the connection field itself rather than one keyed entry. The field is cached
// per filter and sort argument variant, so dropping it by name alone is what clears
// every variant; a keyed eviction would leave a filtered or sorted view serving a
// stale page.
const evictRepositoriesField = (cache, organizationGid) =>
  cache.evict({
    id: cache.identify({ __typename: TYPENAME_ORGANIZATION, id: organizationGid }),
    fieldName: 'artifactRegistryRepositories',
  });

export const evictRepositoriesList =
  (organizationGid) =>
  (cache, { data }) => {
    if (data.createRepository.errors.length) return;

    evictRepositoriesField(cache, organizationGid);
    cache.gc();
  };

// The repository entity goes too, not just the list: the cache keys the type on `name`
// (see cache_config.js), so a cached entity would otherwise outlive the repository and
// let the detail route read it back as though it still existed.
export const evictDeletedRepository =
  (organizationGid, name) =>
  (cache, { data }) => {
    if (data.deleteRepository.errors.length) return;

    cache.evict({
      id: cache.identify({ __typename: TYPENAME_ARTIFACT_REGISTRY_REPOSITORY, name }),
    });
    evictRepositoriesField(cache, organizationGid);
    cache.gc();
  };
