import initSecurityDashboard from 'ee/security_dashboard/security_dashboard_init';
import { DASHBOARD_TYPE_GROUP } from 'ee/security_dashboard/constants';

initSecurityDashboard(document.getElementById('js-group-security-dashboard'), DASHBOARD_TYPE_GROUP);
