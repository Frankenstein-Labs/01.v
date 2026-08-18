import { convertToGraphQLId } from '~/graphql_shared/utils';

const TYPENAME_VIRTUAL_REGISTRY = 'VirtualRegistries::Packages::Maven::Registry';
const TYPENAME_UPSTREAM_REGISTRY = 'VirtualRegistries::Packages::Maven::Upstream';

export const convertToMavenRegistryGraphQLId = (id) =>
  convertToGraphQLId(TYPENAME_VIRTUAL_REGISTRY, id);

export const convertToMavenUpstreamGraphQLId = (id) =>
  convertToGraphQLId(TYPENAME_UPSTREAM_REGISTRY, id);
