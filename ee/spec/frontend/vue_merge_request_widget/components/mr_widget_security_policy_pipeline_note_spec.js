import { GlIcon, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MrWidgetSecurityPolicyPipelineNote from 'ee/vue_merge_request_widget/components/mr_widget_security_policy_pipeline_note.vue';

describe('MrWidgetSecurityPolicyPipelineNote', () => {
  let wrapper;

  const policiesPath = '/group/project/-/security/policies';

  function createComponent({ securityPoliciesPath = policiesPath } = {}) {
    wrapper = shallowMountExtended(MrWidgetSecurityPolicyPipelineNote, {
      propsData: {
        mr: {
          securityPoliciesPath,
        },
      },
      stubs: {
        GlSprintf,
      },
    });
  }

  const findNote = () => wrapper.findByTestId('security-policy-pipeline-note');
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findViewPoliciesLink = () => wrapper.findByTestId('view-policies-link');

  beforeEach(() => {
    createComponent();
  });

  it('renders the note container', () => {
    expect(findNote().exists()).toBe(true);
  });

  it('renders a warning icon', () => {
    expect(findIcon().props('name')).toBe('status-alert');
    expect(findIcon().props('variant')).toBe('warning');
  });

  it('displays the failure message', () => {
    expect(findNote().text()).toContain(
      'Merge request pipeline has passed, but a security policy requires all pipelines to succeed. Another pipeline for this commit has failed.',
    );
  });

  it('renders the View policies link with correct href', () => {
    const link = findViewPoliciesLink();

    expect(link.exists()).toBe(true);
    expect(link.attributes('href')).toBe(policiesPath);
    expect(link.text()).toBe('View policies');
  });
});
