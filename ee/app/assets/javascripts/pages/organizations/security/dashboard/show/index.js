import initSecurityDashboard from 'ee/security_dashboard/security_dashboard_init';
import { DASHBOARD_TYPE_ORGANIZATION } from 'ee/security_dashboard/constants';

initSecurityDashboard(
  document.getElementById('js-organization-security-dashboard'),
  DASHBOARD_TYPE_ORGANIZATION,
);
