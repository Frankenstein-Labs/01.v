import { filterItems } from 'ee/pages/admin/application_settings/ci_cd/helpers';

describe('CI/CD helpers', () => {
  const Yml = (name) => ({ name, id: name, key: name });
  it.each`
    allItems                                                       | searchTerm | result
    ${{ CatA: [Yml('test'), Yml('node')], CatB: [Yml('test')] }}   | ${'t'}     | ${[{ text: 'CatA', options: [{ text: 'test', value: 'test' }] }, { text: 'CatB', options: [{ text: 'test', value: 'test' }] }]}
    ${{ CatA: [Yml('test'), Yml('tether')], CatB: [Yml('test')] }} | ${'tet'}   | ${[{ text: 'CatA', options: [{ text: 'tether', value: 'tether' }] }]}
    ${{ CatA: [Yml('test'), Yml('node')], CatB: [Yml('test')] }}   | ${'n'}     | ${[{ text: 'CatA', options: [{ text: 'node', value: 'node' }] }]}
    ${{ CatA: [Yml('test'), Yml('node')], CatB: [Yml('test')] }}   | ${'asd'}   | ${[]}
    ${[]}                                                          | ${'x'}     | ${[]}
  `(
    'returns filtered list with correct categories when search term is $searchTerm',
    ({ allItems, searchTerm, result }) => {
      expect(filterItems(allItems, searchTerm)).toEqual(result);
    },
  );
});
