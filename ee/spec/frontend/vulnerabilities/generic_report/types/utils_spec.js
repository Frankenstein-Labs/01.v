import { filterTypesAndLimitListDepth } from 'ee/vulnerabilities/components/generic_report/types/utils';

const MOCK_REPORT_TYPE_UNSUPPORTED = 'MOCK_REPORT_TYPE_UNSUPPORTED';
const REPORT_TYPE_LIST = 'list';
const REPORT_TYPE_NAMED_LIST = 'named-list';
const REPORT_TYPE_TABLE = 'table';
const REPORT_TYPE_TEXT = 'text';
const REPORT_TYPE_URL = 'url';

const TEST_DATA = {
  url: {
    type: REPORT_TYPE_URL,
    name: 'url1',
  },
  list: {
    type: REPORT_TYPE_LIST,
    name: 'rootList',
    items: [
      { type: REPORT_TYPE_URL, name: 'url2' },
      {
        type: REPORT_TYPE_LIST,
        name: 'listDepthOne',
        items: [
          { type: REPORT_TYPE_URL, name: 'url3' },
          {
            type: REPORT_TYPE_LIST,
            name: 'listDepthTwo',
            items: [
              { type: REPORT_TYPE_URL, name: 'url4' },
              {
                type: REPORT_TYPE_LIST,
                name: 'listDepthThree',
                items: [
                  { type: REPORT_TYPE_URL, name: 'url5' },
                  { type: MOCK_REPORT_TYPE_UNSUPPORTED },
                ],
              },
              { type: MOCK_REPORT_TYPE_UNSUPPORTED },
            ],
          },
          { type: MOCK_REPORT_TYPE_UNSUPPORTED },
        ],
      },
      { type: MOCK_REPORT_TYPE_UNSUPPORTED },
    ],
  },
  namedList: {
    type: REPORT_TYPE_NAMED_LIST,
    name: 'rootNamedList',
    items: {
      url1: { type: REPORT_TYPE_URL, name: 'foo' },
      url2: { type: REPORT_TYPE_URL, name: 'bar' },
      unsupported: { type: MOCK_REPORT_TYPE_UNSUPPORTED },
    },
  },
  table: {
    type: REPORT_TYPE_TABLE,
    header: [
      { type: REPORT_TYPE_TEXT, value: 'foo ' },
      { type: REPORT_TYPE_TEXT, value: 'bar ' },
    ],
    rows: [
      [
        { type: REPORT_TYPE_TEXT, value: 'foo' },
        { type: REPORT_TYPE_TEXT, value: 'bar' },
      ],
    ],
  },
};

describe('ee/vulnerabilities/components/generic_report/types/utils', () => {
  describe('filterTypesAndLimitListDepth', () => {
    const getRootList = (reportsData) => reportsData.list;
    const getListWithDepthOne = (reportsData) => reportsData.list.items[1];
    const getListWithDepthTwo = (reportsData) => reportsData.list.items[1].items[1];
    const includesType = (type) => (items) =>
      items.find(({ type: currentType }) => currentType === type) !== undefined;
    const includesListItem = includesType(REPORT_TYPE_LIST);
    const includesUnsupportedType = includesType(MOCK_REPORT_TYPE_UNSUPPORTED);

    describe.each`
      depth | getListAtCurrentDepth
      ${1}  | ${getRootList}
      ${2}  | ${getListWithDepthOne}
      ${3}  | ${getListWithDepthTwo}
    `('with nested lists at depth: "$depth"', ({ depth, getListAtCurrentDepth }) => {
      const filteredData = filterTypesAndLimitListDepth(TEST_DATA, { maxDepth: depth });

      it('filters list items', () => {
        expect(includesListItem(getListAtCurrentDepth(TEST_DATA).items)).toBe(true);
        expect(includesListItem(getListAtCurrentDepth(filteredData).items)).toBe(false);
      });

      it('filters items with types that are not supported', () => {
        expect(includesUnsupportedType(getListAtCurrentDepth(TEST_DATA).items)).toBe(true);
        expect(includesUnsupportedType(getListAtCurrentDepth(filteredData).items)).toBe(false);
      });
    });

    describe('with named lists', () => {
      const filteredData = filterTypesAndLimitListDepth(TEST_DATA);

      it('filters items with types that are not supported', () => {
        expect(includesUnsupportedType(filteredData.namedList.items)).toBe(false);
      });

      it('transforms the items object into an array of report-items with labels', () => {
        expect(filteredData.namedList.items).toEqual([
          { label: 'url1', type: REPORT_TYPE_URL, name: 'foo' },
          { label: 'url2', type: REPORT_TYPE_URL, name: 'bar' },
        ]);
      });
    });

    describe('with tables', () => {
      const filteredData = filterTypesAndLimitListDepth(TEST_DATA);
      it('adds a key to each header item', () => {
        expect(filteredData.table.header).toMatchObject([{ key: 'column_0' }, { key: 'column_1' }]);
      });

      it(`transforms the "rows" array into an object with it's keys corresponding to the header keys`, () => {
        expect(filteredData.table.rows[0]).toMatchObject({
          column_0: TEST_DATA.table.rows[0][0],
          column_1: TEST_DATA.table.rows[0][1],
        });
      });
    });
  });
});
