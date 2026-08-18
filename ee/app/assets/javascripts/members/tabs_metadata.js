import { __ } from '~/locale';
import { TABS as CE_TABS } from '~/members/tabs_metadata';
import PromotionRequestsTabApp from './promotion_requests/components/app.vue';
import promotionRequestsTabStore from './promotion_requests/store/index';
import { MEMBERS_TAB_TYPES, TAB_QUERY_PARAM_VALUES } from './constants';

export const TABS = [
  ...CE_TABS,
  {
    namespace: MEMBERS_TAB_TYPES.promotionRequest,
    title: __('Role promotions'),
    attrs: { 'data-testid': 'promotion-request-tab' },
    queryParamValue: TAB_QUERY_PARAM_VALUES.promotionRequest,
    component: PromotionRequestsTabApp,
    store: promotionRequestsTabStore,
    hideExportButton: true,
    lazy: true,
  },
  {
    namespace: MEMBERS_TAB_TYPES.banned,
    title: __('Banned'),
    queryParamValue: TAB_QUERY_PARAM_VALUES.banned,
  },
];
