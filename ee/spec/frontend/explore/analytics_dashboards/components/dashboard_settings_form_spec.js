import { GlFormInput, GlFormTextarea } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DashboardSettingsForm from 'ee/explore/analytics_dashboards/components/dashboard_settings_form.vue';

describe('DashboardSettingsForm', () => {
  let wrapper;

  const defaultProps = {
    value: {
      title: '',
      description: '',
    },
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DashboardSettingsForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findTitleInput = () => wrapper.findComponent(GlFormInput);
  const findDescriptionTextarea = () => wrapper.findComponent(GlFormTextarea);

  describe('value prop validation', () => {
    const { validator } = DashboardSettingsForm.props.value;

    it('requires title property in value prop', () => {
      expect(
        validator({
          description: 'test',
        }),
      ).toBe(false);
    });

    it('requires description property in value prop', () => {
      expect(
        validator({
          title: 'test',
        }),
      ).toBe(false);
    });
  });

  describe('default values on mount', () => {
    beforeEach(() => {
      createComponent({
        value: {
          title: 'Initial Title',
          description: 'Initial Description',
        },
      });
    });

    it('reflects title from value prop in the input', () => {
      expect(findTitleInput().props('value')).toBe('Initial Title');
    });

    it('reflects description from value prop in the textarea', () => {
      expect(findDescriptionTextarea().props('value')).toBe('Initial Description');
    });

    it('does not disable inputs when not loading', () => {
      expect(findTitleInput().props('disabled')).toBe(false);
      expect(findDescriptionTextarea().props('disabled')).toBe(false);
    });
  });

  describe('input events', () => {
    beforeEach(() => {
      createComponent({
        value: {
          title: 'Initial Title',
          description: 'Initial Description',
        },
      });
    });

    it('emits input event when title is updated', async () => {
      await findTitleInput().vm.$emit('input', 'Updated Title');

      expect(wrapper.emitted('input')).toHaveLength(1);
      expect(wrapper.emitted('input')[0][0]).toEqual({
        title: 'Updated Title',
        description: 'Initial Description',
      });
    });

    it('emits input event when description is updated', async () => {
      await findDescriptionTextarea().vm.$emit('input', 'Updated Description');

      expect(wrapper.emitted('input')).toHaveLength(1);
      expect(wrapper.emitted('input')[0][0]).toEqual({
        title: 'Initial Title',
        description: 'Updated Description',
      });
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({
        value: {
          title: 'Test Title',
          description: 'Test Description',
        },
        isLoading: true,
      });
    });

    it('disables title input', () => {
      expect(findTitleInput().props('disabled')).toBe(true);
    });

    it('disables description textarea', () => {
      expect(findDescriptionTextarea().props('disabled')).toBe(true);
    });
  });
});
