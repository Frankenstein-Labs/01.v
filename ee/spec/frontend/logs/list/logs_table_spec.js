import { GlTable, GlLabel } from '@gitlab/ui';
import {
  GL_COLOR_NEUTRAL_300,
  GL_COLOR_BLUE_400,
  GL_COLOR_ORANGE_200,
  GL_COLOR_RED_500,
} from '@gitlab/ui/src/tokens/build/js/tokens';
import { nextTick } from 'vue';
import LogsTable from 'ee/logs/list/logs_table.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { mockLogs } from '../mock_data';

describe('LogsTable', () => {
  let wrapper;

  const mountComponent = ({ logs = mockLogs } = {}) => {
    wrapper = mountExtended(LogsTable, {
      propsData: {
        logs,
      },
    });
  };

  const getRows = () => wrapper.findComponent(GlTable).findAll(`[data-testid="log-row"]`);
  const getRow = (idx) => getRows().at(idx);
  const clickRow = async (idx) => {
    getRow(idx).trigger('click');
    await nextTick();
  };

  it('renders logs as table', () => {
    mountComponent();

    const rows = getRows();
    expect(rows).toHaveLength(mockLogs.length);
    mockLogs.forEach((m, i) => {
      const row = getRows().at(i);
      expect(row.find(`[data-testid="log-timestamp"]`).text()).toBe(
        formatDate(m.timestamp, `mmm dd yyyy HH:MM:ss.l Z`),
      );
      expect(row.find(`[data-testid="log-service"]`).text()).toBe(m.service_name);
      expect(row.find(`[data-testid="log-message"]`).text()).toBe(m.body);
    });
  });

  describe('label', () => {
    it.each([
      [1, 'trace', GL_COLOR_NEUTRAL_300],
      [2, 'trace2', GL_COLOR_NEUTRAL_300],
      [3, 'trace3', GL_COLOR_NEUTRAL_300],
      [4, 'trace4', GL_COLOR_NEUTRAL_300],
      [5, 'debug', GL_COLOR_NEUTRAL_300],
      [6, 'debug2', GL_COLOR_NEUTRAL_300],
      [7, 'debug3', GL_COLOR_NEUTRAL_300],
      [8, 'debug4', GL_COLOR_NEUTRAL_300],
      [9, 'info', GL_COLOR_BLUE_400],
      [10, 'info2', GL_COLOR_BLUE_400],
      [11, 'info3', GL_COLOR_BLUE_400],
      [12, 'info4', GL_COLOR_BLUE_400],
      [13, 'warn', GL_COLOR_ORANGE_200],
      [14, 'warn2', GL_COLOR_ORANGE_200],
      [15, 'warn3', GL_COLOR_ORANGE_200],
      [16, 'warn4', GL_COLOR_ORANGE_200],
      [17, 'error', GL_COLOR_RED_500],
      [18, 'error2', GL_COLOR_RED_500],
      [19, 'error3', GL_COLOR_RED_500],
      [20, 'error4', GL_COLOR_RED_500],
      [21, 'fatal', GL_COLOR_RED_500],
      [22, 'fatal2', GL_COLOR_RED_500],
      [23, 'fatal3', GL_COLOR_RED_500],
      [24, 'fatal4', GL_COLOR_RED_500],
      [100, 'debug', GL_COLOR_NEUTRAL_300],
      [0, 'debug', GL_COLOR_NEUTRAL_300],
    ])('sets the proper label when log severity is %d', (severity, title, color) => {
      mountComponent({
        logs: [{ severity_number: severity }],
      });
      const label = wrapper.findComponent(GlLabel);
      expect(label.props('backgroundColor')).toBe(color);
      expect(label.props('title')).toBe(title);
    });
  });

  it('emits log-selected on row-clicked', async () => {
    mountComponent();

    await clickRow(0);
    expect(wrapper.emitted('log-selected')[0]).toEqual([{ fingerprint: mockLogs[0].fingerprint }]);
  });
});
