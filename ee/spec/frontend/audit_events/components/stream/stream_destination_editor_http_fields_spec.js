import { GlTableLite } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import StreamDestinationEditorHttpFields from 'ee/audit_events/components/stream/stream_destination_editor_http_fields.vue';
import { MAX_HEADERS } from 'ee/audit_events/constants';
import { newStreamDestination } from '../../mock_data';
import { mockHttpTypeDestination } from '../../mock_data/consolidated_api';

describe('StreamDestinationEditorHttpFields', () => {
  let wrapper;

  const createComponent = ({ mountFn = shallowMountExtended, props = {}, provide = {} } = {}) => {
    wrapper = mountFn(StreamDestinationEditorHttpFields, {
      propsData: {
        ...props,
      },
      provide: {
        maxHeaders: MAX_HEADERS,
        ...provide,
      },
    });
  };

  const findDestinationUrl = () => wrapper.findComponentByTestId('destination-url');
  const findVerificationToken = () => wrapper.findComponentByTestId('verification-token');
  const findEmptyHeadersText = () => wrapper.findByTestId('no-header-created');
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);
  const findHeadersTable = () => wrapper.findComponent(GlTableLite);
  const findHeadersRows = () => findHeadersTable().find('tbody').findAll('tr');
  const findAddHeaderButton = () => wrapper.findByTestId('add-header-row-button');
  const findHeaderDeleteButton = (trIdx) =>
    findHeadersRows().at(trIdx).find('[data-testid="header-delete-button"]');
  const findHeaderNameInput = (trIdx) =>
    findHeadersRows().at(trIdx).find('[data-testid="header-name-input"]');
  const findHeaderNameInputComponent = (trIdx) =>
    findHeadersRows().at(trIdx).findComponent('[data-testid="header-name-input"]');
  const findHeaderValueInput = (trIdx) =>
    findHeadersRows().at(trIdx).find('[data-testid="header-value-input"]');
  const findHeaderValueInputComponent = (trIdx) =>
    findHeadersRows().at(trIdx).findComponent('[data-testid="header-value-input"]');
  const findHeaderActiveInput = (trIdx) =>
    findHeadersRows().at(trIdx).find('[data-testid="header-active-input"]');

  describe('when creating a new destination', () => {
    beforeEach(() => {
      createComponent({
        props: {
          value: newStreamDestination,
          isEditing: false,
        },
      });
    });

    it('does not disable destination url field', () => {
      expect(findDestinationUrl().props('disabled')).toBe(false);
    });

    it('renders empty state for headers', () => {
      expect(findEmptyHeadersText().text()).toBe('No header created yet.');
    });
  });

  describe('when editing a destination', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mountExtended,
        props: {
          value: mockHttpTypeDestination[0],
          isEditing: true,
        },
      });
    });

    it('renders the fields correctly', () => {
      expect(findDestinationUrl().props('disabled')).toBe(true);
      expect(findDestinationUrl().props('value')).toBe('http://destination1.local');
      expect(findVerificationToken().props('value')).toBe('mockSecretToken');
      expect(findClipboardButton().props('text')).toBe('mockSecretToken');
      expect(findHeaderNameInputComponent(0).props('value')).toBe('key1');
      expect(findHeaderValueInputComponent(0).props('value')).toBe('test');
      expect(findHeaderActiveInput(0).attributes('value')).toBe('true');
    });

    it('removes existing header when clicking on delete button', async () => {
      expect(findHeadersRows()).toHaveLength(1);

      await findHeaderDeleteButton(0).trigger('click');

      expect(findHeadersRows()).toHaveLength(0);
    });

    it('adds a new header when clicking on the add header button', async () => {
      expect(findHeadersRows()).toHaveLength(1);

      await findAddHeaderButton().trigger('click');

      expect(findHeadersRows()).toHaveLength(2);
      expect(findHeaderNameInputComponent(1).props('value')).toBe('');
      expect(findHeaderValueInputComponent(1).props('value')).toBe('');
      expect(findHeaderActiveInput(1).attributes('value')).toBe('true');
    });

    it('emits input when header value changed', async () => {
      await findHeaderActiveInput(0).setChecked(false);

      expect(wrapper.emitted().input[0][0].config.headers).toMatchObject({
        key1: {
          value: 'test',
          active: false,
        },
      });
    });

    it('invalidates second header if it has the same name', async () => {
      await findAddHeaderButton().trigger('click');

      await findHeaderNameInput(1).setValue('key2');
      await findHeaderValueInput(1).setValue('test');

      expect(findHeaderNameInputComponent(1).props('state')).toBe(true);

      await findHeaderNameInput(1).setValue('key1');

      expect(findHeaderNameInputComponent(1).props('state')).toBe(false);
    });

    it('does not allow adding headers when maxHeaders reached', () => {
      createComponent({
        mountFn: mountExtended,
        props: {
          value: mockHttpTypeDestination[0],
          isEditing: true,
        },
        provide: {
          maxHeaders: 1,
        },
      });

      expect(findAddHeaderButton().exists()).toBe(false);
      expect(wrapper.text().replace(/\s+/g, ' ')).toContain(
        'Maximum of 1 HTTP headers has been reached.',
      );
    });
  });
});
