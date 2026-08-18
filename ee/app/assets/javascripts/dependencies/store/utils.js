import createGraphQLClient from '~/lib/graphql';

export const extractGroupNamespace = (endpoint) => {
  const match = endpoint.match(/groups\/(.*)\/-\/dependencies.json/);
  return match ? match[1] : '';
};

export const filterPathBySearchTerm = (data = [], searchTerm = '') => {
  if (!searchTerm?.length) return data;

  return data.filter((item) => item.location.path.toLowerCase().includes(searchTerm.toLowerCase()));
};

export const hasDependencyList = ({ dependencies }) => Array.isArray(dependencies);
export const isValidResponse = ({ data }) => Boolean(data && hasDependencyList(data));

export const graphQLClient = createGraphQLClient();
