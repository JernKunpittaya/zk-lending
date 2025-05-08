import _ from "lodash"
import numbro from "numbro"

export const formatter = {
  usd: (value: any) =>
    numbro(value).formatCurrency({
      thousandSeparated: true,
      mantissa: 2,
      optionalMantissa: true,
      trimMantissa: true,
    }),
  number: (value: any) =>
    numbro(value).format({
      thousandSeparated: true,
      mantissa: 4,
      optionalMantissa: true,
      trimMantissa: true,
    }),
  percent: (value: any) =>
    numbro(value).format({
      thousandSeparated: true,
      mantissa: 2,
      optionalMantissa: true,
      output: "percent",
    }),
}
