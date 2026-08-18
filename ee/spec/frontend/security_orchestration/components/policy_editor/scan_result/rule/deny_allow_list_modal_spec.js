import { GlModal, GlTableLite } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import DenyAllowListModal from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list_modal.vue';
import DenyAllowLicenses from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_licenses.vue';
import DenyAllowExceptions from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list_exceptions.vue';
import { UNKNOWN_LICENSE } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { NO_EXCEPTION_KEY } from 'ee/security_orchestration/components/policy_editor/constants';

describe('DenyAllowListModal', () => {
  let wrapper;

  const LICENSES = [
    {
      text: 'License 1',
      value: 'license_1',
    },
    {
      text: 'License 2',
      value: 'license_2',
    },
  ];

  const createComponent = ({ propsData = {}, provide = {}, ...options } = {}) => {
    wrapper = mountExtended(DenyAllowListModal, {
      propsData,
      provide: {
        parsedSoftwareLicenses: [],
        ...provide,
      },
      stubs: {
        GlModal: stubComponent(GlModal, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
      ...options,
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableRows = () => findTable().find('tbody').findAll('tr');
  const findLicenses = () => wrapper.findAllComponents(DenyAllowLicenses);
  const findExceptions = () => wrapper.findAllComponents(DenyAllowExceptions);
  const findAddLicenseButton = () => wrapper.findComponentByTestId('add-license');
  const findRemoveLicenseButton = () => wrapper.findComponentByTestId('remove-license');
  const findTooltip = () =>
    getBinding(wrapper.findByTestId('add-license-tooltip').element, 'gl-tooltip');

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders table with one selected row', () => {
      expect(findTable().exists()).toBe(true);
      expect(findLicenses()).toHaveLength(1);
      expect(findExceptions()).toHaveLength(1);

      expect(findModal().props('title')).toBe('Edit denylist');
      expect(findModal().props('size')).toBe('lg');
      expect(findModal().props('actionPrimary').text).toBe('Save denylist');
    });

    it('adds new license row', async () => {
      expect(findTableRows()).toHaveLength(1);

      await findAddLicenseButton().vm.$emit('click');

      expect(findTableRows()).toHaveLength(2);
    });

    it('adds removes license row', async () => {
      await findAddLicenseButton().vm.$emit('click');
      expect(findTableRows()).toHaveLength(2);

      await findRemoveLicenseButton().vm.$emit('click');
      expect(findTableRows()).toHaveLength(1);
    });
  });

  describe('selecting a license', () => {
    it('selects multiple licenses', async () => {
      createComponent({
        provide: {
          parsedSoftwareLicenses: LICENSES,
        },
      });

      await findAddLicenseButton().vm.$emit('click');

      const licenses = findLicenses();

      expect(licenses.at(0).props('allLicenses')).toEqual([UNKNOWN_LICENSE, ...LICENSES]);

      await licenses.at(0).vm.$emit('select', LICENSES[0], LICENSES[0]);
      await licenses.at(1).vm.$emit('select', LICENSES[1], LICENSES[1]);

      await findModal().vm.$emit('primary');

      expect(wrapper.emitted('select-licenses')).toEqual([
        [
          [
            { exceptions: [], license: LICENSES[0] },
            { exceptions: [], license: LICENSES[1] },
          ],
        ],
      ]);
    });

    it.each`
      title                   | parsedLicenses
      ${'without duplicates'} | ${LICENSES}
      ${'with duplicates'}    | ${[...LICENSES, LICENSES[0], LICENSES[1]]}
    `(
      'disables add license button when all licenses already selected $title',
      async ({ parsedLicenses }) => {
        createComponent({
          provide: {
            parsedSoftwareLicenses: parsedLicenses,
          },
          directives: {
            GlTooltip: createMockDirective('gl-tooltip'),
          },
          propsData: {
            licenses: [...LICENSES.map((license) => ({ license }))],
          },
        });

        await findAddLicenseButton().vm.$emit('click');

        expect(findAddLicenseButton().props('disabled')).toBe(true);

        expect(findTooltip().value).toMatchObject({
          disabled: false,
          title: 'All licenses have been selected',
        });
      },
    );

    it('resets licenses when type changes', async () => {
      createComponent({
        provide: {
          parsedSoftwareLicenses: LICENSES,
        },
        propsData: {
          licenses: LICENSES.map((license) => ({ license })),
        },
      });

      expect(findTableRows()).toHaveLength(2);

      await wrapper.setProps({ licenses: [] });

      expect(findTableRows()).toHaveLength(1);
      expect(findLicenses().at(0).props('selected')).toEqual(undefined);
    });

    it('emits on cancel', async () => {
      createComponent({
        provide: {
          parsedSoftwareLicenses: LICENSES,
        },
      });

      await findAddLicenseButton().vm.$emit('click');

      const licenses = findLicenses();

      expect(licenses.at(0).props('allLicenses')).toEqual([UNKNOWN_LICENSE, ...LICENSES]);

      await licenses.at(0).vm.$emit('select', LICENSES[0], LICENSES[0]);
      await licenses.at(1).vm.$emit('select', LICENSES[1], LICENSES[1]);

      await findModal().vm.$emit('canceled');

      expect(wrapper.emitted('select-licenses')).toEqual([[[]]]);
    });
  });

  describe('selecting exceptions', () => {
    const VALID_EXCEPTIONS = ['test@project', 'test1@project'];

    it('selects exceptions for selected license', () => {
      createComponent({
        provide: {
          parsedSoftwareLicenses: LICENSES,
        },
        propsData: {
          licenses: LICENSES.map((license) => ({ license, exceptions: [] })),
        },
      });

      findExceptions().at(0).vm.$emit('input', VALID_EXCEPTIONS);
      findModal().vm.$emit('primary');

      expect(wrapper.emitted('select-licenses')).toEqual([
        [
          [
            { exceptions: VALID_EXCEPTIONS, license: LICENSES[0] },
            { exceptions: [], license: LICENSES[1] },
          ],
        ],
      ]);
    });

    it('renders selected exceptions', () => {
      createComponent({
        provide: {
          parsedSoftwareLicenses: LICENSES,
        },
        propsData: {
          licenses: LICENSES.map((license) => ({ license, exceptions: VALID_EXCEPTIONS })),
        },
      });

      expect(findExceptions().at(0).props('exceptions')).toEqual(VALID_EXCEPTIONS);
      expect(findExceptions().at(0).props('isDeniedList')).toBe(true);
      expect(findExceptions().at(1).props('exceptions')).toEqual(VALID_EXCEPTIONS);
    });

    it('selects exception type end resets exceptions', () => {
      createComponent({
        provide: {
          parsedSoftwareLicenses: LICENSES,
        },
        propsData: {
          licenses: LICENSES.map((license) => ({ license, exceptions: VALID_EXCEPTIONS })),
        },
      });

      findExceptions().at(0).vm.$emit('select-exception-type', NO_EXCEPTION_KEY);
      findModal().vm.$emit('primary');

      expect(wrapper.emitted('select-licenses')).toEqual([
        [
          [
            { exceptions: [], license: LICENSES[0] },
            { exceptions: VALID_EXCEPTIONS, license: LICENSES[1] },
          ],
        ],
      ]);
    });
  });
});
