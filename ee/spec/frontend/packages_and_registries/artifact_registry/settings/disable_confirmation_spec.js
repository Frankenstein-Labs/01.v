import { GlModal } from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import DisableConfirmation from 'ee/packages_and_registries/artifact_registry/settings/disable_confirmation.vue';
import { REGISTRY_HANDLE } from '../mock_data';

describe('ArtifactRegistryDisableConfirmation', () => {
  let wrapper;

  const findModal = () => wrapper.findComponent(GlModal);
  const findPhraseLabel = () => wrapper.findByTestId('confirm-danger-phrase');
  // The dialog fills the shared confirmation's body slot, so the copy is anchored on a
  // testid of its own rather than on the default the slot replaces.
  const findConsequenceParagraphs = () => wrapper.findByTestId('disable-consequences').findAll('p');
  const findConfirmationInput = () => wrapper.findComponentByTestId('confirm-danger-field');
  const findPrimaryAction = () => findModal().props('actionPrimary');
  const findPrimaryActionAttributes = (attribute) => findPrimaryAction().attributes[attribute];

  const createComponent = ({ loading = false } = {}) => {
    wrapper = mountExtended(DisableConfirmation, {
      propsData: { handle: REGISTRY_HANDLE, visible: true, loading },
      // The real GlModal renders its content only once shown, so its body is unreachable
      // here. Stubbing it renders the slots and keeps `actionPrimary` readable, which is
      // where the destructive button's state lives.
      stubs: { GlModal: stubComponent(GlModal) },
    });
  };

  const type = (value) => findConfirmationInput().vm.$emit('input', value);

  beforeEach(() => createComponent());

  describe('what the dialog says', () => {
    it('titles the dialog as the destructive-confirmation dialogs elsewhere are titled', () => {
      expect(findModal().props('title')).toBe('Are you absolutely sure?');
    });

    it('says what it is about to do, then what it does to the projects using the registry', () => {
      expect(findConsequenceParagraphs().wrappers.map((paragraph) => paragraph.text())).toEqual([
        'You are about to disable Artifact Registry.',
        'This will affect all projects currently using this registry.',
      ]);
    });

    it('names the registry handle as the phrase that has to be typed', () => {
      expect(findPhraseLabel().text()).toBe(`Enter the following to confirm: ${REGISTRY_HANDLE}`);
    });

    it('names the destructive action after what it does, and marks it as destructive', () => {
      expect(findPrimaryAction().text).toBe('Disable Artifact Registry');
      expect(findPrimaryActionAttributes('variant')).toBe('danger');
    });
  });

  describe('the confirmation gate', () => {
    it('keeps the destructive action unavailable until the typed value matches the handle', async () => {
      expect(findPrimaryActionAttributes('disabled')).toBe(true);

      await type('my-regist');

      expect(findPrimaryActionAttributes('disabled')).toBe(true);

      await type(`${REGISTRY_HANDLE}-staging`);

      expect(findPrimaryActionAttributes('disabled')).toBe(true);

      await type(REGISTRY_HANDLE);

      expect(findPrimaryActionAttributes('disabled')).toBe(false);
    });

    // A handle is lowercase throughout its charset, so a case variant is the same handle
    // typed differently, and the shared confirmation's case-folded compare is accepted.
    it('reads a case variant of the handle as the same handle, not as a different one', async () => {
      await type(REGISTRY_HANDLE.toUpperCase());

      expect(findPrimaryActionAttributes('disabled')).toBe(false);
    });

    it('hands the confirmation back to its caller rather than disabling the registry itself', async () => {
      await type(REGISTRY_HANDLE);
      findModal().vm.$emit('primary');

      expect(wrapper.emitted('confirm')).toHaveLength(1);
    });
  });

  describe('the dialog state', () => {
    it('opens on the visibility its caller sets', () => {
      expect(findModal().props('visible')).toBe(true);
    });

    it('hands a dismissal back to its caller rather than closing itself', () => {
      findModal().vm.$emit('change', false);

      expect(wrapper.emitted('change')).toEqual([[false]]);
    });

    it('leaves the destructive action idle while nothing is running', () => {
      expect(findPrimaryActionAttributes('loading')).toBe(false);
    });

    it('reports a run in progress on the destructive action', () => {
      createComponent({ loading: true });

      expect(findPrimaryActionAttributes('loading')).toBe(true);
    });
  });
});
