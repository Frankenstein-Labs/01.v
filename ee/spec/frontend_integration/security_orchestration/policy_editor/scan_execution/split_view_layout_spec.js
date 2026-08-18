import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import * as utils from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/from_yaml';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import AdvancedEditorToggle from 'ee/security_orchestration/components/policy_editor/advanced_editor_toggle.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import { SCAN_EXECUTION_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import { navigateToCustomMode } from '../utils';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { mockDastActionScanExecutionManifest } from './mocks';

describe('Split View', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = mountExtended(App, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        glFeatures,
        ...provide,
      },
    });
  };

  const findScanTypeSelector = () => wrapper.findComponentByTestId('scan-type-selector');
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findAdvancedEditorToggle = () => wrapper.findComponent(AdvancedEditorToggle);

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(SCAN_EXECUTION_POLICY_TYPE);
  });

  describe('rendering', () => {
    let createPolicyObjectMock;
    beforeEach(async () => {
      await createWrapper({
        provide: {
          policyEditorEnabled: true,
          namespaceType: 'group',
        },
      });
      await navigateToCustomMode(wrapper);

      findAdvancedEditorToggle().vm.$emit('enable-advanced-editor', true);

      createPolicyObjectMock = jest
        .spyOn(utils, 'createPolicyObject')
        .mockImplementation(() => ({ policy: {}, parsingError: {} }));
    });

    it('updates policy only once when update via rule mode', async () => {
      await findScanTypeSelector().vm.$emit('select', REPORT_TYPE_DAST);
      expect(createPolicyObjectMock).toHaveBeenCalledTimes(0);
    });

    it('updated policy when yaml is updated', async () => {
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockDastActionScanExecutionManifest);

      expect(createPolicyObjectMock).toHaveBeenCalledTimes(2);
    });
  });
});
