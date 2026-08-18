import '~/pages/projects/show/index';
import initTierBadgeTrigger from 'ee/groups/init_tier_badge_trigger';
import initVueAlerts from '~/vue_alerts';
import { initComplianceInfo } from './init_compliance_info';
import { initDuoOtelInfo } from './init_duo_otel_info';

initVueAlerts();
initTierBadgeTrigger();
initComplianceInfo();
initDuoOtelInfo();
