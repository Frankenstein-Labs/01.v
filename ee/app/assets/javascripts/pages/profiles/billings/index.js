import initSubscriptions from 'ee/billings/subscriptions';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import PricingInformationApp from 'ee/billings/pricing_information/components/app.vue';

initSubscriptions();
initSimpleApp('#js-pricing-information', PricingInformationApp);
