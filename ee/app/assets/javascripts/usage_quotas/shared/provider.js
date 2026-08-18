import VueApollo from 'vue-apollo';
import createClient from '~/lib/graphql';
import { createCustomersDotClient } from 'ee/lib/customers_dot_graphql';
import { resolvers } from './resolvers';

const gitlabClient = createClient(resolvers);
const customersDotClient = createCustomersDotClient();

export default new VueApollo({
  defaultClient: gitlabClient,
  clients: {
    gitlabClient,
    customersDotClient,
  },
});
