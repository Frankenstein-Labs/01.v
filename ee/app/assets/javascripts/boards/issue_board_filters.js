import issueBoardFiltersCE from '~/boards/issue_board_filters';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import searchIterationQuery from '../work_items/list/graphql/search_iterations.query.graphql';

export default function issueBoardFilters(apollo, fullPath, isGroupBoard) {
  const boardType = isGroupBoard ? NAMESPACE_GROUP : NAMESPACE_PROJECT;

  const fetchIterations = (searchTerm) => {
    const id = Number(searchTerm);
    let variables = { fullPath, search: searchTerm, isProject: !isGroupBoard };

    if (!Number.isNaN(id) && searchTerm !== '') {
      variables = { fullPath, id, isProject: !isGroupBoard };
    }

    return apollo
      .query({
        query: searchIterationQuery,
        variables,
      })
      .then(({ data }) => {
        return data[boardType]?.iterations.nodes;
      });
  };

  const { fetchLabels } = issueBoardFiltersCE(apollo, fullPath, isGroupBoard);

  return {
    fetchLabels,
    fetchIterations,
  };
}
