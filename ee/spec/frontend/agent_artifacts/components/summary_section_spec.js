import { GlAttributeList } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SummarySection from 'ee/agent_artifacts/components/summary_section.vue';
import { formatDate } from '~/lib/utils/datetime_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';

const EM_DASH = '—';

const ROW_LABELS = [
  'Author ID',
  'Author name',
  'Target type',
  'Target details',
  'Event type',
  'IP address',
  'Timestamp',
];

describe('SummarySection', () => {
  let wrapper;

  const mockEvent = {
    author: {
      id: 'gid://gitlab/User/42',
      name: 'Scott Hampton',
    },
    eventName: 'tool_execution',
    ipAddress: '127.0.0.1',
    createdAt: '2024-01-01T12:00:00Z',
  };

  const targetType = 'Ai::DuoWorkflows::Workflow';
  const targetDetails = 'false_positive_detection/v1 session 1908';

  const createComponent = ({ event = mockEvent, props = {} } = {}) => {
    wrapper = shallowMountExtended(SummarySection, {
      propsData: {
        event,
        targetType,
        targetDetails,
        ...props,
      },
    });
  };

  const findAttributeList = () => wrapper.findComponent(GlAttributeList);
  const findItems = () => findAttributeList().props('items');
  const rowLabels = () => findItems().map((item) => item.label);
  const rowValue = (label) => findItems().find((item) => item.label === label)?.text;

  describe('rows', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders each label inline with its value', () => {
      expect(findAttributeList().props('layout')).toBe('horizontal');
    });

    it('renders all summary rows in order', () => {
      expect(rowLabels()).toEqual(ROW_LABELS);
    });

    it('does not render any entity rows', () => {
      expect(rowLabels()).not.toContain('Entity ID');
      expect(rowLabels()).not.toContain('Entity type');
      expect(rowLabels()).not.toContain('Entity path');
    });
  });

  describe('with a fully populated event', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the author id from the GraphQL id', () => {
      expect(rowValue('Author ID')).toBe(String(getIdFromGraphQLId(mockEvent.author.id)));
    });

    it('renders the author name', () => {
      expect(rowValue('Author name')).toBe('Scott Hampton');
    });

    it('renders the target rows from the passed props', () => {
      expect(rowValue('Target type')).toBe(targetType);
      expect(rowValue('Target details')).toBe(targetDetails);
    });

    it('renders the event type', () => {
      expect(rowValue('Event type')).toBe('tool_execution');
    });

    it('renders the ip address', () => {
      expect(rowValue('IP address')).toBe('127.0.0.1');
    });

    it('renders the formatted timestamp', () => {
      expect(rowValue('Timestamp')).toBe(formatDate(mockEvent.createdAt, LONG_DATE_FORMAT_WITH_TZ));
    });
  });

  describe('with a blank target', () => {
    beforeEach(() => {
      createComponent({ props: { targetType: '', targetDetails: '' } });
    });

    it('renders an em-dash rather than a blank row', () => {
      expect(rowValue('Target type')).toBe(EM_DASH);
      expect(rowValue('Target details')).toBe(EM_DASH);
    });
  });

  describe('with a missing author', () => {
    beforeEach(() => {
      createComponent({ event: { ...mockEvent, author: null } });
    });

    it('renders an em-dash for the author rows', () => {
      expect(rowValue('Author ID')).toBe(EM_DASH);
      expect(rowValue('Author name')).toBe(EM_DASH);
    });
  });

  describe('with a missing timestamp', () => {
    beforeEach(() => {
      createComponent({ event: { ...mockEvent, createdAt: null } });
    });

    it('renders an em-dash for the timestamp', () => {
      expect(rowValue('Timestamp')).toBe(EM_DASH);
    });
  });
});
