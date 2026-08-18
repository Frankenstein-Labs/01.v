import Papa from 'papaparse';
import { downloadCsv } from 'ee/orbit/utils/csv_export';

describe('downloadCsv', () => {
  let createElementSpy;
  let clickSpy;
  let anchorEl;

  beforeEach(() => {
    clickSpy = jest.fn();
    anchorEl = { click: clickSpy };
    createElementSpy = jest.spyOn(document, 'createElement').mockReturnValue(anchorEl);
    URL.revokeObjectURL = jest.fn();
  });

  afterEach(() => {
    createElementSpy.mockRestore();
  });

  it('generates a CSV and triggers a download', () => {
    downloadCsv([
      { type: 'User', id: 1, username: 'admin' },
      { type: 'User', id: 2, username: 'dev' },
    ]);

    expect(createElementSpy).toHaveBeenCalledWith('a');
    expect(anchorEl.href).toContain('blob:');
    expect(anchorEl.download).toBe('orbit-results.csv');
    expect(clickSpy).toHaveBeenCalled();
    expect(URL.revokeObjectURL).toHaveBeenCalled();
  });

  it('uses a custom filename when provided', () => {
    downloadCsv([{ type: 'User', id: 1 }], 'custom.csv');

    expect(anchorEl.download).toBe('custom.csv');
  });

  it('does nothing when rows are empty', () => {
    downloadCsv([]);

    expect(createElementSpy).not.toHaveBeenCalledWith('a');
    expect(clickSpy).not.toHaveBeenCalled();
  });

  it('generates correct headers from row keys', () => {
    const unparseSpy = jest.spyOn(Papa, 'unparse');

    downloadCsv([{ type: 'User', id: 1, username: 'admin', email: 'a@b.com' }]);

    const csvArg = unparseSpy.mock.calls[0][0];
    const headers = Object.keys(csvArg[0]);

    expect(headers).toEqual(['type', 'id', 'username', 'email']);

    unparseSpy.mockRestore();
  });

  describe('formula injection protection', () => {
    it.each([['=cmd()'], ['+1234'], ['-negative'], ['@mention']])(
      'sanitizes value starting with %s',
      (input) => {
        const unparseSpy = jest.spyOn(Papa, 'unparse');

        downloadCsv([{ value: input }]);

        const sanitizedRow = unparseSpy.mock.calls[0][0][0];

        expect(sanitizedRow.value).toMatch(/^'/);

        unparseSpy.mockRestore();
      },
    );

    it('does not prefix safe values', () => {
      const unparseSpy = jest.spyOn(Papa, 'unparse');

      downloadCsv([{ value: 'hello' }]);

      const sanitizedRow = unparseSpy.mock.calls[0][0][0];

      expect(sanitizedRow.value).toBe('hello');

      unparseSpy.mockRestore();
    });

    it('converts null and undefined to empty strings', () => {
      const unparseSpy = jest.spyOn(Papa, 'unparse');

      downloadCsv([{ a: null, b: undefined }]);

      const sanitizedRow = unparseSpy.mock.calls[0][0][0];

      expect(sanitizedRow.a).toBe('');
      expect(sanitizedRow.b).toBe('');

      unparseSpy.mockRestore();
    });
  });
});
