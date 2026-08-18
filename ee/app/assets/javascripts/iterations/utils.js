import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { newDate } from '~/lib/utils/datetime/date_calculation_utility';

/**
 * The first argument is two date strings in formatted in ISO 8601 (YYYY-MM-DD)
 * If the startDate year is the same as the current year, the start date
 * year is omitted.
 *
 * The second argument is a boolean switch that determines whether the
 * iteration period should be formatted for use in an issue or not. There are
 * intended design differences in the way the period is formatted for uses like
 * a board issue card or the issue sidebar. This argument is optional and
 * defaults to false.
 *
 * @returns {string}
 *
 * ex. "Oct 1, 2021 - Oct 10, 2022" if start and due dates have different years, regardless of current year.
 *
 * "Oct 1 - 10, 2021" if start and due dates are both in 2021, current year === 2021.
 */
export function getIterationPeriod({ startDate, dueDate }) {
  return localeDateFormat.asDate.formatRange(newDate(startDate), newDate(dueDate));
}

/**
 * Sort iteration cadences by the specified field
 */
const sortCadences = (cadences, sortBy) => {
  return cadences.sort((a, b) => {
    const titleA = a[sortBy].toLowerCase();
    const titleB = b[sortBy].toLowerCase();
    return titleA.localeCompare(titleB);
  });
};

/**
 * Group a list of iterations by cadence.
 *
 * @param iterations A list of iterations
 * @return {Array} A list of cadences
 */
export function groupByIterationCadences(iterations) {
  const cadences = [];
  iterations.forEach((iteration) => {
    if (!iteration.iterationCadence) {
      return;
    }
    const { title, id } = iteration.iterationCadence;
    const cadenceIteration = {
      id: iteration.id,
      title: iteration.title,
      period: getIterationPeriod(iteration),
    };
    const cadence = cadences.find((c) => c.title === title);
    if (cadence) {
      cadence.iterations.push(cadenceIteration);
    } else {
      cadences.push({ title, iterations: [cadenceIteration], id });
    }
  });
  return sortCadences(cadences, 'title');
}

export function groupOptionsByIterationCadences(iterations) {
  const cadences = [];
  iterations.forEach((iteration) => {
    if (!iteration.iterationCadence) {
      return;
    }
    const { title } = iteration.iterationCadence;
    const cadenceIteration = {
      value: iteration.id,
      title: iteration.title,
      text: getIterationPeriod(iteration),
    };
    const cadence = cadences.find((c) => c.text === title);
    if (cadence) {
      cadence.options.push(cadenceIteration);
    } else {
      cadences.push({ text: title, options: [cadenceIteration] });
    }
  });
  return sortCadences(cadences, 'text');
}
