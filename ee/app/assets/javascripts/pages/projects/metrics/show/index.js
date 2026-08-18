import DetailsIndex from 'ee/metrics/details_index.vue';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

initSimpleApp('#js-observability-metrics-details', DetailsIndex, { withApolloProvider: true });
