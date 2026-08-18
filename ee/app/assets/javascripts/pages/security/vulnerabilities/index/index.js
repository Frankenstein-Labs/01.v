import { DASHBOARD_TYPE_INSTANCE } from 'ee/security_dashboard/constants';
import vulnerabilityReportInit from 'ee/security_dashboard/vulnerability_report_init';

vulnerabilityReportInit(document.getElementById('js-vulnerabilities'), DASHBOARD_TYPE_INSTANCE);
