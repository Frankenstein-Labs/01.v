import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import {
  extractFilterQueryParameters,
  extractPaginationQueryParameters,
} from '~/analytics/shared/utils';
import { defaultClient } from '~/analytics/shared/graphql/client';
import { parseBoolean } from '~/lib/utils/common_utils';
import { buildCycleAnalyticsInitialData } from '../shared/utils';
import CycleAnalytics from './components/base.vue';
import createStore from './store';

Vue.use(GlToast);
Vue.use(VueApollo);

const apolloProvider = new VueApollo({ defaultClient });

export default () => {
  const el = document.querySelector('#js-cycle-analytics');
  const {
    emptyStateSvgPath,
    noDataSvgPath,
    noAccessSvgPath,
    newValueStreamPath,
    editValueStreamPath,
    hasScopedLabelsFeature,
    enableTasksByTypeChart,
  } = el.dataset;
  const initialData = buildCycleAnalyticsInitialData(el.dataset);
  const store = createStore();

  const pagination = extractPaginationQueryParameters(window.location.search);
  const { selectedAuthor, selectedMilestone, selectedAssigneeList, selectedLabelList } =
    extractFilterQueryParameters(window.location.search);

  store.dispatch('initializeCycleAnalytics', {
    ...initialData,
    selectedAuthor,
    selectedMilestone,
    selectedAssigneeList,
    selectedLabelList,
    pagination,
  });

  return initVueApp({
    el,
    name: 'CycleAnalyticsApp',
    apolloProvider,
    store,
    provide: {
      newValueStreamPath,
      editValueStreamPath,
      hasScopedLabelsFeature: parseBoolean(hasScopedLabelsFeature),
    },
    component: CycleAnalytics,
    props: {
      emptyStateSvgPath,
      noDataSvgPath,
      noAccessSvgPath,
      enableTasksByTypeChart: parseBoolean(enableTasksByTypeChart),
    },
  });
};
