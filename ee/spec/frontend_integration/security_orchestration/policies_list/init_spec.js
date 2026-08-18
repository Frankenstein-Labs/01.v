import initPoliciesList from 'ee/security_orchestration/security_policies_list';
import setWindowLocation from 'helpers/set_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { DEFAULT_PROVIDE } from './mocks';

const EMPTY_DIV = document.createElement('div');

const TEST_DATASET = {
  disableSecurityPolicyProject: 'false',
  disableScanPolicyUpdate: 'false',
};

describe('Policies List', () => {
  let vm;
  let root;

  beforeEach(() => {
    window.gon.features = {};
    root = document.createElement('div');
    document.body.appendChild(root);

    setWindowLocation(`${TEST_HOST}/-/security/policies`);
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
    vm = initPoliciesList(el, type);
  };

  const createEmptyComponent = () => {
    vm = initPoliciesList(null, null);
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
