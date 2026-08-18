import { nextTick } from 'vue';
import { GlModal, GlForm, GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { VULNERABILITY_STATE_OBJECTS, DISMISSAL_REASONS } from 'ee/vulnerabilities/constants';
import StateModal from 'ee/vulnerabilities/components/state_modal.vue';
import { dismissalDescriptions } from 'ee_jest/vulnerabilities/mock_data';

const { dismissed, ...VULNERABILITY_STATE_OBJECTS_WITHOUT_DISMISSED } = VULNERABILITY_STATE_OBJECTS;
const statesWithoutDismissed = Object.values(VULNERABILITY_STATE_OBJECTS_WITHOUT_DISMISSED).map(
  (stateObject) => stateObject.state,
);
const dismissalReasons = Object.keys(DISMISSAL_REASONS);

describe('StateModal', () => {
  let wrapper;

  const createWrapper = ({
    modalId = 'modal-id',
    state = 'detected',
    dismissalReason,
    comment,
    stubs,
  } = {}) => {
    wrapper = shallowMountExtended(StateModal, {
      propsData: { modalId, state, dismissalReason, comment },
      provide: { dismissalDescriptions },
      stubs: { GlFormGroup, ...stubs },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findStatusFormGroup = () => wrapper.findByTestId('vulnerability-status-form-group');
  const findStatusListbox = () => wrapper.findComponentByTestId('vulnerability-status-listbox');
  const findCommentFormGroup = () => wrapper.findByTestId('vulnerability-comment-form-group');
  const findCommentInput = () => wrapper.findComponentByTestId('vulnerability-comment-input');

  const submitForm = () => {
    wrapper.findComponent(GlForm).vm.$emit('submit', {
      preventDefault: jest.fn(),
    });
  };

  beforeEach(createWrapper);

  it('passes correct props to modal', () => {
    expect(findModal().props()).toMatchObject({
      size: 'sm',
      modalId: 'modal-id',
      title: 'Change status',
      actionPrimary: { text: 'Change status' },
      actionCancel: { text: 'Cancel' },
    });
  });

  /**
   * When the modal is shown, we reset the state, such that we start from
   * a clean slate after closing the modal. We do not do this on hidden because
   * the prop values might still change after an API call.
   */
  it('resets after show event', async () => {
    findStatusListbox().vm.$emit('select', 'mitigating_control');
    await nextTick();
    findCommentInput().vm.$emit('input', 'test comment');

    findModal().vm.$emit('show');
    await nextTick();

    expect(findStatusListbox().props('selected')).toBe('detected');
    expect(findCommentInput().attributes('value')).toBe(undefined);
  });

  describe('status', () => {
    it('shows form group', () => {
      expect(findStatusFormGroup().attributes()).toMatchObject({
        label: 'Status',
        invalidfeedback: 'New status must be different than current status.',
      });
    });

    it.each(statesWithoutDismissed)(
      'passes state as selected prop for "%s" and has correct toggle text',
      (state) => {
        createWrapper({ state });

        expect(findStatusListbox().props('selected')).toBe(state);
        expect(findStatusListbox().props('toggleText')).toBe(
          VULNERABILITY_STATE_OBJECTS[state].buttonText,
        );
      },
    );

    it.each(dismissalReasons)(
      'passes dismissal reason as selected prop for "%s" and correct toggle text',
      (dismissalReason) => {
        createWrapper({ state: 'dismissed', dismissalReason });

        expect(findStatusListbox().props('selected')).toBe(dismissalReason);
        expect(findStatusListbox().props('toggleText')).toBe(
          `Dismissed: ${DISMISSAL_REASONS[dismissalReason]}`,
        );
      },
    );

    it('passes null if dismissed without dismissal reason', () => {
      createWrapper({ state: 'dismissed' });

      expect(findStatusListbox().props('selected')).toBe(null);
      expect(findStatusListbox().props('toggleText')).toBe('Dismissed');
    });

    it('shows correct items', () => {
      createWrapper({ stubs: { GlCollapsibleListbox } });

      const statesText = Object.values(VULNERABILITY_STATE_OBJECTS_WITHOUT_DISMISSED)
        .map((item) => `${item.dropdownText} ${item.dropdownDescription}`)
        .join('');
      const dismissalsText = Object.entries(DISMISSAL_REASONS)
        .map(([key, value]) => `${value} ${dismissalDescriptions[key]}`)
        .join('');
      expect(findStatusListbox().text()).toMatchInterpolatedText(`${statesText} ${dismissalsText}`);
    });

    it('updates status when selecting item', async () => {
      findStatusListbox().vm.$emit('select', 'resolved');
      await nextTick();
      expect(findStatusListbox().props('selected')).toBe('resolved');
    });

    it('does not clear comment when status is updated', async () => {
      findCommentInput().vm.$emit('input', 'test comment');
      findStatusListbox().vm.$emit('select', 'resolved');
      await nextTick();
      expect(findCommentInput().attributes('value')).toBe('test comment');
    });
  });

  describe('comment', () => {
    it('shows form group', () => {
      expect(findCommentFormGroup().attributes()).toMatchObject({
        label: 'Comment',
      });
    });

    it('shows required comment label when dismissing', () => {
      createWrapper({ state: 'dismissed' });

      expect(findCommentFormGroup().attributes()).toMatchObject({
        label: 'Comment (required)',
        invalidfeedback: 'A comment is required when dismissing.',
      });
    });

    it('shows existing comment', () => {
      createWrapper({ comment: 'test comment' });
      expect(findCommentInput().attributes('value')).toBe('test comment');
    });
  });

  describe('validation', () => {
    it('is not valid when status is not changed', async () => {
      submitForm();
      await nextTick();
      expect(findStatusFormGroup().attributes('state')).toBe(undefined);
      expect(wrapper.emitted('change')).toBeUndefined();
    });

    it('is valid when status is changed', async () => {
      findStatusListbox().vm.$emit('select', 'resolved');
      submitForm();
      await nextTick();
      expect(findStatusFormGroup().attributes('state')).toBe('true');
      expect(wrapper.emitted('change')).toMatchObject([
        [{ action: 'resolve', comment: null, dismissalReason: undefined }],
      ]);
    });

    it('is not valid when not providing comment for dismissed status', async () => {
      findStatusListbox().vm.$emit('select', 'acceptable_risk');
      submitForm();
      await nextTick();
      expect(findCommentFormGroup().attributes('state')).toBe(undefined);
      expect(wrapper.emitted('change')).toBeUndefined();
    });

    it('is valid when providing comment for dismissed status', async () => {
      findStatusListbox().vm.$emit('select', 'acceptable_risk');
      findCommentInput().vm.$emit('input', 'test comment');
      submitForm();
      await nextTick();
      expect(findCommentFormGroup().attributes('state')).toBe('true');
      expect(wrapper.emitted('change')).toMatchObject([
        [{ action: 'dismiss', comment: 'test comment', dismissalReason: 'ACCEPTABLE_RISK' }],
      ]);
    });
  });
});
