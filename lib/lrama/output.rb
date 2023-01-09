require "erb"
require "forwardable"
require "lrama/report"

module Lrama
  class Output
    extend Forwardable
    include Report::Duration

    attr_reader :grammar_file_path, :context, :grammar

    def_delegators "@context", :yyfinal, :yylast, :yyntokens, :yynnts, :yynrules, :yynstates,
                               :yymaxutok, :yypact_ninf, :yytable_ninf

    def_delegators "@grammar", :eof_symbol, :error_symbol, :undef_symbol, :accept_symbol

    def initialize(out:, output_file_path:, template_name:, grammar_file_path:, header_out: nil, header_file_path: nil, context:, grammar:)
      @out = out
      @output_file_path = output_file_path
      @template_name = template_name
      @grammar_file_path = grammar_file_path
      @header_out = header_out
      @header_file_path = header_file_path
      @context = context
      @grammar = grammar
    end

    def render
      report_duration(:render) do
        erb = ERB.new(File.read(template_file), nil, '-')
        erb.filename = template_file
        tmp = erb.result_with_hash(context: @context, output: self)
        tmp = replace_special_variables(tmp, @output_file_path)
        @out << tmp

        if @header_file_path
          erb = ERB.new(File.read(header_template_file), nil, '-')
          erb.filename = header_template_file
          tmp = erb.result_with_hash(context: @context, output: self)
          tmp = replace_special_variables(tmp, @header_file_path)

          if @header_out
            @header_out << tmp
          else
            File.open(@header_file_path, "w+") do |f|
              f << tmp
            end
          end
        end
      end
    end

    # A part of b4_token_enums
    def token_enums
      str = ""

      @context.yytokentype.each do |s_value, token_id, display_name|
        s = sprintf("%s = %d%s", s_value, token_id, token_id == yymaxutok ? "" : ",")

        if display_name
          str << sprintf("    %-30s /* %s  */\n", s, display_name)
        else
          str << sprintf("    %s\n", s)
        end
      end

      str
    end

    # b4_symbol_enum
    def symbol_enum
      str = ""

      last_sym_number = @context.yysymbol_kind_t.last[1]
      @context.yysymbol_kind_t.each do |s_value, sym_number, display_name|
        s = sprintf("%s = %d%s", s_value, sym_number, (sym_number == last_sym_number) ? "" : ",")

        if display_name
          str << sprintf("  %-40s /* %s  */\n", s, display_name)
        else
          str << sprintf("  %s\n", s)
        end
      end

      str
    end

    def yytranslate
      int_array_to_string(@context.yytranslate)
    end

    def yyrline
      int_array_to_string(@context.yyrline)
    end

    def yytname
      string_array_to_string(@context.yytname) + " YY_NULLPTR"
    end

    # b4_int_type_for
    def int_type_for(ary)
      min = ary.min
      max = ary.max

      case
      when (-127 <= min && min <= 127) && (-127 <= max && max <= 127)
        "yytype_int8"
      when (0 <= min && min <= 255) && (0 <= max && max <= 255)
        "yytype_uint8"
      when (-32767 <= min && min <= 32767) && (-32767 <= max && max <= 32767)
        "yytype_int16"
      when (0 <= min && min <= 65535) && (0 <= max && max <= 65535)
        "yytype_uint16"
      else
        "int"
      end
    end

    def symbol_actions_for_printer
      str = ""

      @grammar.symbols.each do |sym|
        next unless sym.printer

        str << <<-STR
    case #{sym.enum_name}: /* #{sym.comment}  */
#line #{sym.printer.lineno} "#{@grammar_file_path}"
         #{sym.printer.translated_code(sym.tag)}
#line [@oline@] [@ofile@]
        break;

        STR
      end

      str
    end

    # b4_user_actions
    def user_actions
      str = ""

      @context.states.rules.each do |rule|
        next unless rule.code

        rule = rule
        code = rule.code
        spaces = " " * (code.column - 1)

        str << <<-STR
  case #{rule.id + 1}: /* #{rule.as_comment}  */
#line #{code.line} "#{@grammar_file_path}"
#{spaces}#{rule.translated_code}
#line [@oline@] [@ofile@]
    break;

        STR
      end

      str << <<-STR

#line [@oline@] [@ofile@]
      STR

      str
    end

    # b4_parse_param
    def parse_param
      # Omit "{}"
      @grammar.parse_param[1..-2]
    end

    # b4_user_formals
    def user_formals
      if @grammar.parse_param
        ", #{parse_param}"
      else
        ""
      end
    end

    # b4_table_value_equals
    def table_value_equals(table, value, literal, symbol)
      if literal < table.min || table.max < literal
        "0"
      else
        "((#{value}) == #{symbol})"
      end
    end

    def template_basename
      File.basename(template_file)
    end

    def aux
      @grammar.aux
    end

    def int_array_to_string(ary)
      last = ary.count - 1

      s = ary.each_with_index.each_slice(10).map do |slice|
        str = "  "

        slice.each do |e, i|
          str << sprintf("%6d%s", e, (i == last) ? "" : ",")
        end

        str
      end

      s.join("\n")
    end

    def spec_mapped_header_file
      @header_file_path
    end

    def b4_cpp_guard__b4_spec_mapped_header_file
      if @header_file_path
        "YY_YY_" + @header_file_path.gsub(/[^a-zA-Z_0-9]+/, "_").upcase + "_INCLUDED"
      else
        ""
      end
    end

    private

    def template_file
      File.join(template_dir, @template_name)
    end

    def header_template_file
      File.join(template_dir, "bison/yacc.h")
    end

    def template_dir
      File.expand_path("../../../template", __FILE__)
    end

    def string_array_to_string(ary)
      str = ""
      tmp = " "

      ary.each do |s|
        s = s.gsub('\\', '\\\\\\\\')
        s = s.gsub('"', '\\"')

        if (tmp + s + " \"\",").length > 75
          str << tmp << "\n"
          tmp = "  \"#{s}\","
        else
          tmp << " \"#{s}\","
        end
      end

      str << tmp
    end

    def replace_special_variables(str, ofile)
      str.each_line.with_index(1).map do |line, i|
        line.gsub!("[@oline@]", (i + 1).to_s)
        line.gsub!("[@ofile@]", "\"#{ofile}\"")
        line
      end.join
    end
  end
end
