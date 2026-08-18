import { nextTick } from 'vue';
import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SeverityModal from 'ee/vulnerabilities/components/severity_modal.vue';

describe('SeverityModal', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(SeverityModal, {
      propsData: {
        modalId: 'modal-id',
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findSeverityFormGroup = () => wrapper.findByTestId('severity-form-group');
  const findSeverity = () => wrapper.findComponentByTestId('severity');
  const findCommentFormGroup = () => wrapper.findByTestId('comment-form-group');
  const findComment = () => wrapper.findComponentByTestId('comment');
  const validationStateOf = (formGroup) => Boolean(formGroup.attributes('state'));
  const saveChange = () => findModal().vm.$emit('primary', { preventDefault: () => {} });

  beforeEach(() => {
    createComponent();
  });

  it('passes correct props', () => {
    expect(findModal().props()).toMatchObject({
      size: 'sm',
      modalId: 'modal-id',
      title: 'Change severity',
    });
  });

  it('can select a severity', async () => {
    expect(findSeverity().props('selected')).toBe(null);

    findSeverity().vm.$emit('select', 'high');
    await nextTick();

    expect(findSeverity().props('selected')).toBe('high');
  });

  it('emits a change event', () => {
    const severity = 'info';
    const comment = 'Not applicable';

    findSeverity().vm.$emit('select', severity);
    findComment().vm.$emit('input', comment);
    saveChange();

    expect(wrapper.emitted('change')).toStrictEqual([
      [
        {
          newSeverity: severity,
          comment,
        },
      ],
    ]);
  });

  describe('form validation', () => {
    it('requires a severity', async () => {
      findComment().vm.$emit('input', 'comment');
      saveChange();
      await nextTick();

      expect(validationStateOf(findSeverityFormGroup())).toBe(false);
      expect(findSeverityFormGroup().attributes('invalid-feedback')).toBe('Severity is required.');
      expect(wrapper.emitted('change')).toBeUndefined();

      findSeverity().vm.$emit('select', 'high');
      saveChange();
      await nextTick();

      expect(validationStateOf(findSeverityFormGroup())).toBe(true);
      expect(wrapper.emitted('change')).toHaveLength(1);
    });

    it('requires a comment', async () => {
      findSeverity().vm.$emit('select', 'high');
      saveChange();
      await nextTick();

      expect(validationStateOf(findCommentFormGroup())).toBe(false);
      expect(findCommentFormGroup().attributes('invalid-feedback')).toBe('Comment is required.');
      expect(wrapper.emitted('change')).toBeUndefined();

      findComment().vm.$emit('input', 'comment');
      saveChange();
      await nextTick();

      expect(validationStateOf(findCommentFormGroup())).toBe(true);
      expect(wrapper.emitted('change')).toHaveLength(1);
    });
  });
});
