import setWindowLocation from 'helpers/set_window_location_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import {
  getPanelParamName,
  readFromUrl,
  writeToUrl,
} from 'ee/security_dashboard/utils/panel_state_url_sync';

describe('Security Dashboard - Panel State Url Sync', () => {
  const panelId = 'panelId';
  const paramName = 'paramName';

  afterEach(() => {
    setWindowLocation('');
  });

  describe('getPanelParamName', () => {
    it('returns prefixed parameter name', () => {
      const result = getPanelParamName({
        panelId: 'vulnerabilitiesChart',
        paramName: 'groupBy',
      });

      expect(result).toBe('vulnerabilitiesChart.groupBy');
    });
  });

  describe('readFromUrl', () => {
    it('returns default value when parameter does not exist', () => {
      setWindowLocation('');
      expect(
        readFromUrl({
          panelId,
          paramName,
          defaultValue: 'all',
        }),
      ).toBe('all');
    });

    it('returns default value when parameter value is empty', () => {
      setWindowLocation('?panelId.paramName=');
      expect(
        readFromUrl({
          panelId,
          paramName,
          defaultValue: 'all',
        }),
      ).toBe('all');
    });

    it('returns array of values when default value is an array', () => {
      setWindowLocation('?panelId.paramName=a,b');
      expect(
        readFromUrl({
          panelId,
          paramName,
          defaultValue: [],
        }),
      ).toMatchObject(['a', 'b']);
    });

    it('returns number when default value is a number', () => {
      setWindowLocation('?panelId.paramName=15');
      expect(
        readFromUrl({
          panelId,
          paramName,
          defaultValue: 10,
        }),
      ).toBe(15);
    });

    it('returns string value if default value is not array or number', () => {
      setWindowLocation('?panelId.paramName=test');
      expect(
        readFromUrl({
          panelId,
          paramName,
          defaultValue: 'all',
        }),
      ).toBe('test');
    });
  });

  describe('writeToUrl', () => {
    const expectUrlToBe = (url) => {
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({ url, replace: true });
    };

    beforeEach(() => {
      jest.spyOn(urlUtils, 'updateHistory');
    });

    describe('when value is equal to default value', () => {
      it('deletes parameter for string', () => {
        setWindowLocation('?tab=test&panelId.paramName=a');
        writeToUrl({
          panelId,
          paramName,
          value: 'all',
          defaultValue: 'all',
        });

        expectUrlToBe('http://test.host/?tab=test');
      });

      it('deletes parameter for array', () => {
        setWindowLocation('?tab=test&panelId.paramName=a,b');
        writeToUrl({
          panelId,
          paramName,
          value: [],
          defaultValue: [],
        });

        expectUrlToBe('http://test.host/?tab=test');
      });

      it('deletes parameter for number', () => {
        setWindowLocation('?tab=test&panelId.paramName=5');
        writeToUrl({
          panelId,
          paramName,
          value: 10,
          defaultValue: 10,
        });

        expectUrlToBe('http://test.host/?tab=test');
      });
    });

    describe('when value is not equal to default value', () => {
      it('adds new URL parameter if it does not exist yet', () => {
        setWindowLocation('?tab=test');
        writeToUrl({
          panelId,
          paramName,
          value: 'a',
          defaultValue: 'all',
        });

        expectUrlToBe('http://test.host/?tab=test&panelId.paramName=a');
      });

      it('updates URL parameter if it exists already', () => {
        setWindowLocation('?tab=test&panelId.paramName=b');
        writeToUrl({
          panelId,
          paramName,
          value: 'a',
          defaultValue: 'all',
        });

        expectUrlToBe('http://test.host/?tab=test&panelId.paramName=a');
      });

      it('adds URL parameter with comma-separated value for array', () => {
        setWindowLocation('');
        writeToUrl({
          panelId,
          paramName,
          value: ['a', 'b'],
          defaultValue: [],
        });

        expectUrlToBe('http://test.host/?panelId.paramName=a,b');
      });
    });
  });
});
