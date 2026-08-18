import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlFormGroup } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';
import DuoAuditEventStorageForm from 'ee/ai/settings/components/duo_audit_event_storage_form.vue';

describe('DuoAuditEventStorageForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(DuoAuditEventStorageForm, {
        provide: {
          aiAuditEventsStorageEnabled: false,
          aiAuditEventsStorageCascadingSettings: null,
          ...injectedProps,
        },
        propsData: {
          ...props,
        },
        stubs: {
          GlFormCheckbox,
          GlFormGroup,
        },
      }),
    );
  };

  const findTitle = () => wrapper.findComponent(GlFormGroup);
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findCascadingLockIcon = () => wrapper.findComponent(CascadingLockIcon);

  beforeEach(() => {
    createComponent();
  });

  it('has the correct title', () => {
    expect(findTitle().attributes('label')).toBe('AI audit event storage');
  });

  it('has the correct label', () => {
    expect(findCheckbox().text()).toContain('Store AI audit events');
  });

  it('has the correct help text', () => {
    expect(findCheckbox().text()).toContain(
      'When you turn on this setting, GitLab stores new AI audit events to the database or ClickHouse. Real-time streaming of AI audit events is not affected.',
    );
  });

  it('renders the checkbox unchecked by default', () => {
    expect(findCheckbox().props('checked')).toBe(false);
  });

  it.each`
    aiAuditEventsStorageEnabled | description
    ${true}                     | ${'checked'}
    ${false}                    | ${'unchecked'}
  `(
    'renders the checkbox as $description when aiAuditEventsStorageEnabled is set to $aiAuditEventsStorageEnabled',
    ({ aiAuditEventsStorageEnabled }) => {
      createComponent({ injectedProps: { aiAuditEventsStorageEnabled } });

      expect(findCheckbox().props('checked')).toBe(aiAuditEventsStorageEnabled);
    },
  );

  it('emits change event with the new value when the checkbox is toggled', () => {
    findCheckbox().vm.$emit('input', true);
    findCheckbox().vm.$emit('change', true);

    expect(wrapper.emitted('change')).toEqual([[true]]);
  });

  it('disables the checkbox when disabledCheckbox prop is true', () => {
    createComponent({ props: { disabledCheckbox: true } });

    expect(findCheckbox().props('disabled')).toBe(true);
  });

  it('does not disable the checkbox when disabledCheckbox prop is false', () => {
    createComponent({ props: { disabledCheckbox: false } });

    expect(findCheckbox().props('disabled')).toBe(false);
  });

  describe('cascading lock icon', () => {
    it('does not render when cascading settings are null', () => {
      createComponent({ injectedProps: { aiAuditEventsStorageCascadingSettings: null } });

      expect(findCascadingLockIcon().exists()).toBe(false);
    });

    it('does not render when cascading settings are empty', () => {
      createComponent({ injectedProps: { aiAuditEventsStorageCascadingSettings: {} } });

      expect(findCascadingLockIcon().exists()).toBe(false);
    });

    it('renders when cascading settings are present', () => {
      createComponent({
        injectedProps: {
          aiAuditEventsStorageCascadingSettings: {
            lockedByAncestor: false,
            lockedByApplicationSetting: false,
            ancestorNamespace: null,
          },
        },
      });

      expect(findCascadingLockIcon().exists()).toBe(true);
      expect(findCascadingLockIcon().props()).toMatchObject({
        isLockedByGroupAncestor: false,
        isLockedByApplicationSettings: false,
        ancestorNamespace: null,
      });
    });

    it.each`
      lockedByAncestor | lockedByApplicationSetting
      ${true}          | ${false}
      ${false}         | ${true}
    `(
      'disables the checkbox when locked (lockedByAncestor: $lockedByAncestor, lockedByApplicationSetting: $lockedByApplicationSetting)',
      ({ lockedByAncestor, lockedByApplicationSetting }) => {
        createComponent({
          injectedProps: {
            aiAuditEventsStorageCascadingSettings: { lockedByAncestor, lockedByApplicationSetting },
          },
        });

        expect(findCheckbox().props('disabled')).toBe(true);
      },
    );

    it('does not disable the checkbox when not locked', () => {
      createComponent({
        injectedProps: {
          aiAuditEventsStorageCascadingSettings: {
            lockedByAncestor: false,
            lockedByApplicationSetting: false,
          },
        },
      });

      expect(findCheckbox().props('disabled')).toBe(false);
    });
  });
});
