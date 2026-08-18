import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createClient from '~/lib/graphql';
import { gitLabResolvers } from 'ee/subscriptions/graphql/resolvers';

Vue.use(VueApollo);

const gitlabClient = createClient(gitLabResolvers);

export default new VueApollo({
  defaultClient: gitlabClient,
  clients: {
    gitlabClient,
  },
});
