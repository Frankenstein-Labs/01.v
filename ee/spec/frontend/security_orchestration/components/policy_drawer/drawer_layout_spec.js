import { GlSprintf, GlLink } from '@gitlab/ui';
import { trimText } from 'helpers/text_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import {
  DEFAULT_DESCRIPTION_LABEL,
  ENABLED_LABEL,
  NOT_ENABLED_LABEL,
} from 'ee/security_orchestration/components/policy_drawer/constants';
import ScopeInfoRow from 'ee/security_orchestration/components/policy_drawer/scope_info_row.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  mockGroupScanExecutionPolicy,
  mockProjectScanExecutionPolicy,
} from '../../mocks/mock_scan_execution_policy_data';

describe('DrawerLayout component', () => {
  let wrapper;

  const DESCRIPTION = 'This policy enforces pipeline configuration to have a job with DAST scan';
  const TYPE = 'Scan Execution';

  const findCustomDescription = () => wrapper.findByTestId('custom-description-text');
  const findDefaultDescription = () => wrapper.findByTestId('default-description-text');
  const findEnabledText = () => wrapper.findByTestId('enabled-status-text');
  const findNotEnabledText = () => wrapper.findByTestId('not-enabled-status-text');
  const findSourceSection = () => wrapper.findByTestId('policy-source');
  const findScopeInfoRow = () => wrapper.findComponent(ScopeInfoRow);
  const findLink = () => wrapper.findComponent(GlLink);
  const componentStatusText = (status) => (status ? 'does' : 'does not');

  const factory = ({ propsData = {}, provide = {} }) => {
    wrapper = shallowMountExtended(DrawerLayout, {
      provide: {
        namespaceType: NAMESPACE_TYPES.PROJECT,
        ...provide,
      },
      propsData: {
        type: TYPE,
        ...propsData,
      },
      scopedSlots: {
        summary: `<span data-testid="summary-text">Summary</span>`,
        additionalDetails: `<span data-testid="additional-details">More</span>`,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe.each`
    context                 | propsData                                                               | enabled  | hasDescription
    ${'enabled policy'}     | ${{ policy: mockProjectScanExecutionPolicy, description: DESCRIPTION }} | ${true}  | ${true}
    ${'not enabled policy'} | ${{ policy: { ...mockProjectScanExecutionPolicy, enabled: false } }}    | ${false} | ${false}
  `('$context', ({ enabled, hasDescription, propsData }) => {
    beforeEach(() => {
      factory({ propsData });
    });

    it.each`
      component                | status                                  | finder                    | exists             | text
      ${'custom description'}  | ${componentStatusText(hasDescription)}  | ${findCustomDescription}  | ${hasDescription}  | ${DESCRIPTION}
      ${'default description'} | ${componentStatusText(!hasDescription)} | ${findDefaultDescription} | ${!hasDescription} | ${DEFAULT_DESCRIPTION_LABEL}
      ${'enabled text'}        | ${componentStatusText(enabled)}         | ${findEnabledText}        | ${enabled}         | ${ENABLED_LABEL}
      ${'not enabled text'}    | ${componentStatusText(!enabled)}        | ${findNotEnabledText}     | ${!enabled}        | ${NOT_ENABLED_LABEL}
    `('$status render the $component', ({ exists, finder, text }) => {
      const component = finder();
      expect(component.exists()).toBe(exists);
      if (exists) {
        expect(component.text()).toBe(text);
      }
    });

    it('matches the snapshots', () => {
      expect(wrapper.element).toMatchSnapshot();
    });
  });

  describe('source field', () => {
    it('displays correctly for a project-level policy being displayed on a project', () => {
      factory({ propsData: { policy: mockProjectScanExecutionPolicy } });
      expect(findSourceSection().text()).toBe('This is a project-level policy');
    });

    it('displays correctly for a group-level policy being displayed on a group', () => {
      factory({
        propsData: { policy: mockProjectScanExecutionPolicy },
        provide: { namespaceType: NAMESPACE_TYPES.GROUP },
      });
      expect(findSourceSection().text()).toBe('This is a group-level policy');
    });

    it('displays correctly for a instance policy being displayed on a group', () => {
      factory({
        propsData: { policy: { ...mockProjectScanExecutionPolicy, csp: true } },
        provide: { namespaceType: NAMESPACE_TYPES.GROUP },
      });
      expect(findSourceSection().text()).toBe('This is an instance policy');
    });

    describe('inherited', () => {
      it('displays correctly for a group-level policy being displayed on a project', () => {
        factory({ propsData: { policy: mockGroupScanExecutionPolicy } });
        expect(trimText(findSourceSection().text())).toBe(
          'This policy is inherited from parent-group-name',
        );
        expect(findLink().text()).toBe('parent-group-name');
        expect(findLink().attributes('href')).toBe(
          'http://test.host/groups/parent-group-path/-/security/policies',
        );
      });

      it('displays correctly for a instance policy', () => {
        factory({
          propsData: { policy: { ...mockGroupScanExecutionPolicy, csp: true } },
          provide: { namespaceType: NAMESPACE_TYPES.GROUP },
        });
        expect(trimText(findSourceSection().text())).toBe(
          'This instance policy is inherited from parent-group-name',
        );
      });
    });
  });

  describe('policy without source namespace', () => {
    it.each`
      namespaceType              | inherited | expectedResult
      ${NAMESPACE_TYPES.GROUP}   | ${true}   | ${'This policy is inherited'}
      ${NAMESPACE_TYPES.PROJECT} | ${true}   | ${'This policy is inherited'}
      ${NAMESPACE_TYPES.GROUP}   | ${false}  | ${'This is a group-level policy'}
      ${NAMESPACE_TYPES.PROJECT} | ${false}  | ${'This is a project-level policy'}
    `(
      'should not render link for policies without namespace',
      ({ namespaceType, inherited, expectedResult }) => {
        factory({
          propsData: {
            policy: {
              ...mockProjectScanExecutionPolicy,
              source: {
                __typename: 'GroupSecurityPolicySource',
                inherited,
                namespace: undefined,
              },
            },
          },
          provide: { namespaceType },
        });

        expect(findLink().exists()).toBe(false);
        expect(findSourceSection().text()).toBe(expectedResult);
      },
    );
  });

  describe('policy scope', () => {
    it.each`
      namespaceType
      ${NAMESPACE_TYPES.PROJECT}
      ${NAMESPACE_TYPES.GROUP}
    `(`renders policy scope for $namespaceType`, ({ namespaceType }) => {
      factory({
        propsData: {
          policy: mockProjectScanExecutionPolicy,
        },
        provide: {
          namespaceType,
        },
      });

      expect(findScopeInfoRow().exists()).toBe(true);
      expect(findScopeInfoRow().props('isInstanceLevel')).toBe(false);
    });
  });

  it('hides enabled text when showStatus is true', () => {
    factory({ propsData: { policy: mockProjectScanExecutionPolicy, showStatus: false } });

    expect(findEnabledText().exists()).toBe(false);
  });

  it('hides scope info row component when showPolicyScope is true', () => {
    factory({ propsData: { policy: mockProjectScanExecutionPolicy, showPolicyScope: false } });

    expect(findScopeInfoRow().exists()).toBe(false);
  });
});
