require 'spreadsheet'

output_sql = []

book = Spreadsheet.open('sample.xls')
sheet1 = book.worksheet('Sheet1') # can use an index or worksheet name

# make a hash of the first row so we can get the column indexes
cols = Hash[sheet1.row(0).map.with_index.to_a]

# iterate over the rows and build the sql
sheet1.each 1 do |row|

  sql_columns = []
  sql_values = []

# build a cols and values pair for each non-blank entry
  cols.each_key do |key|
    val = row[cols[key]]
    unless val.to_s.size < 1 or key.to_s == "id" # only include non blanks & skip the id col
      sql_columns << key
      sql_values << ((val.is_a?(Numeric)) ? val : "'#{val}'") # wrap in quotes unless it's a numeric
    end

  end

# if the ID col is filled then build an update statement otherwise build an insert
  id = row[cols["id"]]
  if id
    id = id.to_i
    pairs = sql_columns.each_with_index.map { |col, i| "#{col}=#{sql_values[i]}" }
    output_sql << "delete from reviews where parentId = #{id}"
    output_sql << "update reviews set #{pairs.join(",")} where id = #{id}"
  else
    output_sql << "insert into reviews(#{sql_columns.join(",")}) values (#{sql_values.join(',')})"
  end

end

output_sql.each { |sql| puts sql } # output the sql