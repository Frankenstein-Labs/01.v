import { shallowMount } from '@vue/test-utils';
import { GlAlert, GlFormRadio, GlFormGroup, GlSprintf } from '@gitlab/ui';
import DuoAvailabilityForm from 'ee/ai/settings/components/duo_availability_form.vue';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

describe('DuoAvailabilityForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    return shallowMount(DuoAvailabilityForm, {
      stubs: {
        'gl-form-radio': GlFormRadio,
        'gl-sprintf': GlSprintf,
      },
      propsData: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        ...props,
      },
      provide: {
        areDuoSettingsLocked: false,
        duoAvailabilityCascadingSettings: {
          lockedByAncestor: false,
          lockedByApplicationSetting: false,
          ancestorNamespace: null,
        },
        isSaaS: true,
        ...provide,
      },
    });
  };

  const findFormRadioButtons = () => wrapper.findAllComponents(GlFormRadio);
  const findRadioButtonDescriptions = () => wrapper.findAll('.help-text');
  const findCascadingLockIcon = () => wrapper.findComponent(CascadingLockIcon);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findAdminLockedAlert = () => wrapper.findComponent(GlAlert);

  it('displays title', () => {
    wrapper = createComponent();
    expect(findFormGroup().attributes('label')).toContain('GitLab Duo availability');
  });

  it('renders radio buttons with correct labels', () => {
    wrapper = createComponent();
    expect(findFormRadioButtons()).toHaveLength(4);
    expect(findFormRadioButtons().at(0).text()).toContain('Always on');
    expect(findFormRadioButtons().at(1).text()).toContain('On by default');
    expect(findFormRadioButtons().at(2).text()).toContain('Off by default');
    expect(findFormRadioButtons().at(3).text()).toContain('Always off');
  });

  describe('with GitLab.com', () => {
    it('displays correct subtitle', () => {
      wrapper = createComponent({ provide: { isSaaS: true } });
      expect(findFormGroup().attributes('labeldescription')).toContain(
        'Control whether GitLab Duo is available for this group.',
      );
    });

    it('renders radio buttons with correct descriptions', () => {
      wrapper = createComponent({ provide: { isSaaS: true } });
      expect(findRadioButtonDescriptions().at(0).text()).toContain(
        'GitLab Duo is always available. Subgroups and projects cannot opt out.',
      );
      expect(findRadioButtonDescriptions().at(1).text()).toContain(
        'GitLab Duo is available by default. Subgroups and projects can opt out individually.',
      );
      expect(findRadioButtonDescriptions().at(2).text()).toContain(
        'GitLab Duo is unavailable by default. Subgroups and projects can opt in individually.',
      );
      expect(findRadioButtonDescriptions().at(3).text()).toContain(
        'GitLab Duo is always unavailable. Subgroups and projects cannot opt in.',
      );
    });
  });

  describe('with Self-Managed', () => {
    it('displays correct subtitle', () => {
      wrapper = createComponent({ provide: { isSaaS: false } });
      expect(findFormGroup().attributes('labeldescription')).toContain(
        'Control whether GitLab Duo is available for the instance.',
      );
    });

    it('renders radio buttons with correct descriptions', () => {
      wrapper = createComponent({ provide: { isSaaS: false } });
      expect(findRadioButtonDescriptions().at(0).text()).toContain(
        'GitLab Duo is always available. Groups, subgroups, and projects cannot opt out.',
      );
      expect(findRadioButtonDescriptions().at(1).text()).toContain(
        'GitLab Duo is available by default. Groups, subgroups, and projects can opt out individually.',
      );
      expect(findRadioButtonDescriptions().at(2).text()).toContain(
        'GitLab Duo is unavailable by default. Groups, subgroups, and projects can opt in individually.',
      );
      expect(findRadioButtonDescriptions().at(3).text()).toContain(
        'GitLab Duo is always unavailable. Groups, subgroups, and projects cannot opt in.',
      );
    });
  });

  it('emits change event when radio button is selected', () => {
    wrapper = createComponent({ props: { duoAvailability: AVAILABILITY_OPTIONS.ALWAYS_ON } });
    findFormRadioButtons().at(0).vm.$emit('change');
    expect(findFormRadioButtons().at(0).props('value')).toBe(AVAILABILITY_OPTIONS.ALWAYS_ON);
    expect(wrapper.emitted('change')).toHaveLength(1);
    expect(wrapper.emitted('change')[0]).toEqual([AVAILABILITY_OPTIONS.ALWAYS_ON]);
  });

  describe('when areDuoSettingsLocked is true', () => {
    beforeEach(() => {
      wrapper = createComponent({
        provide: {
          areDuoSettingsLocked: true,
        },
      });
    });

    it('disables radio buttons', () => {
      const radios = wrapper.findAllComponents(GlFormRadio);
      radios.wrappers.forEach((radio) => {
        expect(radio.props().disabled).toBe(true);
      });
    });

    it('shows CascadingLockIcon when duoAvailabilityCascadingSettings is provided', () => {
      expect(findCascadingLockIcon().exists()).toBe(true);
    });

    it('passes correct props to CascadingLockIcon', () => {
      expect(findCascadingLockIcon().props()).toMatchObject({
        isLockedByGroupAncestor: false,
        isLockedByApplicationSettings: false,
        ancestorNamespace: null,
      });
    });

    it('does not show CascadingLockIcon when duoAvailabilityCascadingSettings is empty', () => {
      wrapper = createComponent({
        provide: {
          duoAvailabilityCascadingSettings: {},
        },
      });
      expect(findCascadingLockIcon().exists()).toBe(false);
    });

    it('does not show CascadingLockIcon when duoAvailabilityCascadingSettings is null', () => {
      wrapper = createComponent({
        provide: {
          duoAvailabilityCascadingSettings: null,
        },
      });
      expect(findCascadingLockIcon().exists()).toBe(false);
    });
  });

  describe('when areDuoSettingsLocked is false', () => {
    it('does not show CascadingLockIcon', () => {
      wrapper = createComponent();
      expect(findCascadingLockIcon().exists()).toBe(false);
    });
  });

  describe('when duoAvailabilityAdminLocked is true', () => {
    beforeEach(() => {
      wrapper = createComponent({
        provide: {
          duoAvailabilityAdminLocked: true,
        },
      });
    });

    it('disables all radio buttons', () => {
      findFormRadioButtons().wrappers.forEach((radio) => {
        expect(radio.props().disabled).toBe(true);
      });
    });

    it('surfaces the admin-locked alert', () => {
      expect(findAdminLockedAlert().exists()).toBe(true);
      expect(findAdminLockedAlert().props('dismissible')).toBe(false);
      expect(findAdminLockedAlert().text()).toBe(
        'GitLab Duo availability for this group is managed by your instance administrator.',
      );
    });

    it('does not show CascadingLockIcon when only admin-locked', () => {
      expect(findCascadingLockIcon().exists()).toBe(false);
    });
  });

  describe('when duoAvailabilityAdminLocked is false', () => {
    it('does not surface the admin-locked alert', () => {
      wrapper = createComponent();
      expect(findAdminLockedAlert().exists()).toBe(false);
    });

    it('does not disable radio buttons', () => {
      wrapper = createComponent();
      findFormRadioButtons().wrappers.forEach((radio) => {
        expect(radio.props().disabled).toBe(false);
      });
    });
  });
});
