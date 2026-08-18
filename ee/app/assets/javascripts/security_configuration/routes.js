import SecurityConfigurationTabs from './components/group_configuration_tabs.vue';
import ScannerDetails from './components/scan_profiles/scanner_details.vue';
import EnableScanners from './components/enable_scanners_wizard/app.vue';
import EnableScannersSelectApproach from './components/enable_scanners_wizard/select_approach.vue';
import EnableScannersSelectItems from './components/enable_scanners_wizard/select_items.vue';
import EnableScannersSelectScanners from './components/enable_scanners_wizard/select_scanners.vue';
import EnableScannersReview from './components/enable_scanners_wizard/review.vue';
import EnableScannersConfirmation from './components/enable_scanners_wizard/confirmation.vue';
import {
  ROUTE_ENABLE_SCANNERS,
  ROUTE_APPROACH,
  ROUTE_ITEMS,
  ROUTE_SCANNERS,
  ROUTE_REVIEW,
  ROUTE_CONFIRMATION,
} from './components/enable_scanners_wizard/constants';

export const routes = [
  {
    path: '/',
    name: 'security_configuration',
    component: SecurityConfigurationTabs,
  },
  {
    path: '/scanners/:scanner_key',
    name: 'scanner_details',
    component: ScannerDetails,
  },
  {
    path: '/enable_scanners',
    component: EnableScanners,
    children: [
      { path: '', name: ROUTE_ENABLE_SCANNERS, redirect: 'approach' },
      { path: 'approach', name: ROUTE_APPROACH, component: EnableScannersSelectApproach },
      { path: 'items', name: ROUTE_ITEMS, component: EnableScannersSelectItems },
      { path: 'scanners', name: ROUTE_SCANNERS, component: EnableScannersSelectScanners },
      { path: 'review', name: ROUTE_REVIEW, component: EnableScannersReview },
      { path: 'confirm', name: ROUTE_CONFIRMATION, component: EnableScannersConfirmation },
    ],
  },
  { path: '*', redirect: { name: 'security_configuration' } },
];
