import ListIndex from 'ee/logs/list_index.vue';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

initSimpleApp('#js-observability-logs', ListIndex, { withApolloProvider: true });
