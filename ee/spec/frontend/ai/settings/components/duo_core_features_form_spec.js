import { GlLink, GlSprintf, GlFormGroup, GlFormCheckbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';
import DuoCoreFeaturesForm from 'ee/ai/settings/components/duo_core_features_form.vue';
import { DOCS_URL } from '~/constants';

const mockTermsPath = `/handbook/legal/ai-functionality-terms/`;
const duoCoreFeaturesPath = `${DOCS_URL}/user/gitlab_duo/feature_summary/`;
const duoCorePrerequisitesPath = `${DOCS_URL}/user/duo_agent_platform/#prerequisites`;

describe('DuoCoreFeaturesForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {}, glFeatures = {} } = {}) => {
    return shallowMountExtended(DuoCoreFeaturesForm, {
      propsData: {
        disabledCheckbox: false,
        duoCoreFeaturesEnabled: false,
        ...props,
      },
      provide: {
        isSaaS: true,
        glFeatures: {
          noDuoClassicForDuoCoreUsers: true,
          ...glFeatures,
        },
        ...provide,
      },
      stubs: {
        GlLink,
        GlSprintf,
        GlFormGroup,
        GlFormCheckbox,
      },
    });
  };

  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('renders the title', () => {
    expect(wrapper.text()).toMatch('GitLab Duo Core');
  });

  it('renders the subtitle', () => {
    expect(wrapper.text()).toMatch(
      'Allow users without a GitLab Duo Pro or Enterprise seat to access GitLab Duo Agent Platform features',
    );
  });

  it('renders the checkbox with correct label', () => {
    expect(findFormCheckbox().text()).toContain('Turn on GitLab Duo Agent Platform access');
  });

  it('sets initial checkbox state based on duoCoreFeaturesEnabled prop when unselected', () => {
    expect(findFormCheckbox().attributes('checked')).toBe(undefined);
  });

  it('emits change event when checkbox is clicked', () => {
    findFormCheckbox().vm.$emit('change');
    expect(wrapper.emitted('change')).toEqual([[false]]);
  });

  it('renders correct links', () => {
    const glLinks = wrapper.findAllComponents(GlLink);
    const linkHrefs = glLinks.wrappers.map((link) => link.props('href'));

    expect(wrapper.findComponent(PromoPageLink).props('path')).toBe(mockTermsPath);
    expect(linkHrefs).toContain(duoCoreFeaturesPath);
    expect(linkHrefs).toContain(duoCorePrerequisitesPath);
  });

  it('renders correct link text for "Which features are included" in subtitle', () => {
    expect(wrapper.text()).toContain('Which features are included?');
  });

  it('renders correct link text for prerequisites in help text', () => {
    expect(wrapper.text()).toContain(
      'What are the prerequisites for the GitLab Duo Agent Platform',
    );
  });

  it('renders the description', () => {
    expect(wrapper.text()).toMatch(
      'By turning on these features, you accept the GitLab Duo AI Terms unless your organization has a separate agreement with GitLab that governs AI usage.',
    );
  });

  describe('on SaaS', () => {
    beforeEach(() => {
      wrapper = createComponent({ provide: { isSaaS: true } });
    });

    it('renders the namespace description', () => {
      expect(wrapper.text()).toMatch('This setting applies to the top-level group.');
    });
  });

  describe('on Self-Managed', () => {
    beforeEach(() => {
      wrapper = createComponent({ provide: { isSaaS: false } });
    });

    it('renders the instance description', () => {
      expect(wrapper.text()).toMatch('This setting applies to the entire instance.');
    });
  });

  it('leaves the checkbox enabled', () => {
    expect(findFormCheckbox().attributes('disabled')).not.toBeDefined();
  });

  describe('with Duo availability never on', () => {
    it('disables the checkbox', () => {
      wrapper = createComponent({ props: { disabledCheckbox: true } });

      expect(findFormCheckbox().props('disabled')).toBeDefined();
    });
  });

  it('disables checkbox switching from enabled to disabled', async () => {
    wrapper = createComponent({ props: { disabledCheckbox: false } });

    await wrapper.setProps({ disabledCheckbox: true });

    expect(findFormCheckbox().props('disabled')).toBeDefined();
  });

  describe('when no_duo_classic_for_duo_core_users feature flag is disabled', () => {
    beforeEach(() => {
      wrapper = createComponent({ glFeatures: { noDuoClassicForDuoCoreUsers: false } });
    });

    it('renders the legacy subtitle', () => {
      expect(wrapper.text()).toMatch(
        'When this setting is turned on, users can access features included in the GitLab Duo Core add-on',
      );
    });

    it('renders the legacy checkbox label', () => {
      expect(findFormCheckbox().text()).toContain('Turn on features for GitLab Duo Core');
    });

    it('does not render the prerequisites link', () => {
      const glLinks = wrapper.findAllComponents(GlLink);
      const linkHrefs = glLinks.wrappers.map((link) => link.props('href'));

      expect(linkHrefs).not.toContain(duoCorePrerequisitesPath);
    });

    it('does not render prerequisites link text in help text', () => {
      expect(wrapper.text()).not.toContain(
        'What are the prerequisites for the GitLab Duo Agent Platform',
      );
    });

    it('renders the legacy help text without prerequisites', () => {
      expect(wrapper.text()).toMatch(
        'This setting applies to the top-level group. By turning on these features, you accept the GitLab Duo AI Terms unless your organization has a separate agreement with GitLab that governs AI usage.',
      );
    });
  });
});
