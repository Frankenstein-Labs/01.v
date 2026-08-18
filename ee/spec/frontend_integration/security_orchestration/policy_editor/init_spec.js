import initPolicyEditorApp from 'ee/security_orchestration/policy_editor';
import setWindowLocation from 'helpers/set_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { DEFAULT_PROVIDE } from './mocks/mocks';

const EMPTY_DIV = document.createElement('div');

const TEST_DATASET = {
  assignedPolicyProject:
    '{"id":"gid://gitlab/Project/19","name":"Policies - Project","full_path":"gitlab-org/policies-project","branch":"main"}',
  disableSecurityPolicyProject: 'false',
  disableScanPolicyUpdate: 'false',
  globalGroupApproversEnabled: 'true',
  maxActiveScanExecutionPoliciesReached: 'false',
  maxActiveScanResultPoliciesReached: 'false',
  maxActiveVulnerabilityManagementPoliciesReached: 'false',
  maxScanExecutionPoliciesAllowed: '5',
  maxScanResultPoliciesAllowed: '5',
  maxVulnerabilityManagementPoliciesAllowed: '5',
  roleApproverTypes: '["developer", "maintainer", "owner"]',
  softwareLicenses: '["3dfx Glide License"]',
  timezones:
    '[{"identifier":"Etc/GMT+12","name":"International Date Line West","abbr":"-12","offset":-43200,"formatted_offset":"-12:00"}]',
};

describe('Policy Editor', () => {
  let vm;
  let root;

  beforeEach(() => {
    root = document.createElement('div');
    document.body.appendChild(root);

    setWindowLocation(`${TEST_HOST}/-/security/policies/new`);
  });

  afterEach(() => {
    if (vm) {
      vm.$destroy();
    }
    root.remove();
  });

  const createComponent = ({ data, type }) => {
    const el = document.createElement('div');
    Object.assign(el.dataset, { ...DEFAULT_PROVIDE, ...TEST_DATASET, ...data });
    root.appendChild(el);
    vm = initPolicyEditorApp(el, type);
  };

  const createEmptyComponent = () => {
    vm = initPolicyEditorApp(null, null);
  };

  describe('default states', () => {
    it('sets up project-level', () => {
      createComponent({
        data: { namespacePath: 'path/to/project' },
        type: NAMESPACE_TYPES.PROJECT,
      });
      expect(root).not.toStrictEqual(EMPTY_DIV);
    });

    it('sets up group-level', () => {
      createComponent({ data: { namespacePath: 'path/to/group' }, type: NAMESPACE_TYPES.GROUP });
      expect(root).not.toStrictEqual(EMPTY_DIV);
    });
  });

  describe('error states', () => {
    it('does not have an element', () => {
      createEmptyComponent();

      expect(root).toStrictEqual(EMPTY_DIV);
    });
  });
});
