import { GlButton, GlLink, GlSprintf, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ManualSetup from 'ee/integrations/edit/components/google_cloud_iam/manual_setup.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';

describe('ManualSetup', () => {
  const wlifIssuer = 'https://test.com';
  const helpTextPoolId = 'grouprootpath';
  let wrapper;
  const createComponent = () => {
    wrapper = shallowMount(ManualSetup, {
      propsData: {
        wlifIssuer,
        helpTextPoolId,
      },
      stubs: { GlSprintf },
    });
  };

  const findButtons = () => wrapper.findAllComponents(GlButton);
  const findLinks = () => wrapper.findAllComponents(GlLink);
  const findModal = () => wrapper.findComponent(GlModal);
  const findClipboardButtons = () => wrapper.findAllComponents(ClipboardButton);

  beforeEach(() => {
    createComponent();
  });

  describe('Show instructions modal', () => {
    let modalButton;

    beforeEach(() => {
      modalButton = findButtons().at(0);
    });

    it('renders button', () => {
      expect(modalButton.text()).toBe(
        'What if I cannot manage workload identity federation in Google Cloud?',
      );
    });

    it('renders modal when clicked', async () => {
      const modal = findModal();
      expect(modal.isVisible()).toBe(true);

      await modalButton.trigger('click');

      expect(modal.props('modalId')).toBe('google-cloud-iam-non-admin-instructions');
      expect(modal.isVisible()).toBe(true);
      expect(modal.text()).toContain(helpTextPoolId);
    });
  });

  it('renders links to help doc page and corresponding clipboard button (must be an absolute URL)', () => {
    const helpPath = 'http://test.host/help/integration/google_cloud_iam#with-the-google-cloud-cli';
    expect(findLinks().at(1).attributes('href')).toBe(helpPath);
    expect(findClipboardButtons().at(0).props('text')).toBe(helpPath);
  });

  it('show the workload identity federation provider issuer and corresponding clipboard button', () => {
    expect(wrapper.text()).toContain(wlifIssuer);
    expect(findClipboardButtons().at(1).props('text')).toBe(wlifIssuer);
  });

  it('show the recommended pool and corresponding clipboard button', () => {
    expect(wrapper.text()).toContain(helpTextPoolId);
    expect(findClipboardButtons().at(2).props('text')).toBe(helpTextPoolId);
  });
});
