// Handwritten host metadata parser. Never interprets BF/model payload bytes.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace Tartarus.IOAuditV2
{
    public sealed class JsonNumber
    {
        public readonly string Text;
        public JsonNumber(string text) { Text = text; }
    }

    public sealed class MetadataJson : IDisposable
    {
        private readonly TextReader reader;
        private long position;
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false, true);
        public MetadataJson(TextReader input) { reader = input; }
        public static MetadataJson Open(string path)
        {
            return new MetadataJson(new StreamReader(path, Utf8, true, 65536));
        }
        public void Dispose() { reader.Dispose(); }
        private int Peek() { return reader.Peek(); }
        private int Next() { position++; return reader.Read(); }
        private InvalidDataException Bad(string message)
        { return new InvalidDataException("Metadata JSON " + message + " at " + position); }
        private void White()
        {
            while (Peek() == 32 || Peek() == 9 || Peek() == 10 || Peek() == 13) Next();
        }
        private void Take(char expected)
        { White(); if (Next() != expected) throw Bad("expected " + expected); }
        private string String()
        {
            Take('"'); var text = new StringBuilder();
            for (;;)
            {
                int ch = Next();
                if (ch < 0 || ch < 32) throw Bad("string");
                if (ch == '"') break;
                if (ch == '\\')
                {
                    ch = Next();
                    switch (ch)
                    {
                        case '"': case '\\': case '/': text.Append((char)ch); break;
                        case 'b': text.Append('\b'); break;
                        case 'f': text.Append('\f'); break;
                        case 'n': text.Append('\n'); break;
                        case 'r': text.Append('\r'); break;
                        case 't': text.Append('\t'); break;
                        case 'u':
                            int value = 0;
                            for (int i = 0; i < 4; i++)
                            {
                                int h = Next();
                                int digit = h >= '0' && h <= '9' ? h - '0' :
                                    h >= 'a' && h <= 'f' ? h - 'a' + 10 :
                                    h >= 'A' && h <= 'F' ? h - 'A' + 10 : -1;
                                if (digit < 0) throw Bad("unicode escape");
                                value = value * 16 + digit;
                            }
                            text.Append((char)value); break;
                        default: throw Bad("escape");
                    }
                }
                else text.Append((char)ch);
            }
            string result = text.ToString();
            for (int i = 0; i < result.Length; i++)
            {
                if (Char.IsHighSurrogate(result[i]))
                {
                    if (++i >= result.Length || !Char.IsLowSurrogate(result[i])) throw Bad("surrogate");
                }
                else if (Char.IsLowSurrogate(result[i])) throw Bad("surrogate");
            }
            return result;
        }
        private object Literal(string expected, object value)
        {
            foreach (char ch in expected) if (Next() != ch) throw Bad("literal");
            return value;
        }
        private JsonNumber Number()
        {
            var text = new StringBuilder();
            if (Peek() == '-') text.Append((char)Next());
            if (Peek() == '0') text.Append((char)Next());
            else
            {
                if (Peek() < '1' || Peek() > '9') throw Bad("number");
                while (Peek() >= '0' && Peek() <= '9') text.Append((char)Next());
            }
            if (Peek() == '.')
            {
                text.Append((char)Next());
                if (Peek() < '0' || Peek() > '9') throw Bad("fraction");
                while (Peek() >= '0' && Peek() <= '9') text.Append((char)Next());
            }
            if (Peek() == 'e' || Peek() == 'E')
            {
                text.Append((char)Next());
                if (Peek() == '+' || Peek() == '-') text.Append((char)Next());
                if (Peek() < '0' || Peek() > '9') throw Bad("exponent");
                while (Peek() >= '0' && Peek() <= '9') text.Append((char)Next());
            }
            return new JsonNumber(text.ToString());
        }
        private object Value(int depth)
        {
            if (depth > 64) throw Bad("depth");
            White(); int ch = Peek();
            if (ch == '"') return String();
            if (ch == '{')
            {
                Next(); var map = new Dictionary<string, object>(StringComparer.Ordinal);
                White(); if (Peek() == '}') { Next(); return map; }
                for (;;)
                {
                    string key = String(); Take(':');
                    if (map.ContainsKey(key)) throw Bad("duplicate property");
                    map.Add(key, Value(depth + 1)); White(); ch = Next();
                    if (ch == '}') return map;
                    if (ch != ',') throw Bad("object separator");
                }
            }
            if (ch == '[')
            {
                Next(); var list = new List<object>(); White();
                if (Peek() == ']') { Next(); return list; }
                for (;;)
                {
                    list.Add(Value(depth + 1)); White(); ch = Next();
                    if (ch == ']') return list;
                    if (ch != ',') throw Bad("array separator");
                }
            }
            if (ch == 't') return Literal("true", true);
            if (ch == 'f') return Literal("false", false);
            if (ch == 'n') return Literal("null", null);
            if (ch == '-' || (ch >= '0' && ch <= '9')) return Number();
            throw Bad("value");
        }
        private void End() { White(); if (Peek() != -1) throw Bad("trailing data"); }
        public object Read() { object result = Value(0); End(); return result; }
        public void ArrayObjects(Action<Dictionary<string, object>> visit)
        {
            Take('['); White();
            if (Peek() == ']') { Next(); End(); return; }
            for (;;)
            {
                visit(Object(Value(1))); White(); int ch = Next();
                if (ch == ']') { End(); return; }
                if (ch != ',') throw Bad("array separator");
            }
        }
        public static object Parse(string text)
        { using (var json = new MetadataJson(new StringReader(text))) return json.Read(); }
        public static Dictionary<string, object> Object(object value)
        {
            var result = value as Dictionary<string, object>;
            if (result == null) throw new InvalidDataException("Metadata JSON object required");
            return result;
        }
        public static string Text(Dictionary<string, object> value, string key)
        {
            object item; string result;
            if (!value.TryGetValue(key, out item) || (result = item as string) == null)
                throw new InvalidDataException("Metadata string required: " + key);
            return result;
        }
        public static long Integer(Dictionary<string, object> value, string key)
        {
            object item; long result; JsonNumber number;
            if (!value.TryGetValue(key, out item) || (number = item as JsonNumber) == null ||
                !Int64.TryParse(number.Text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out result) || result < 0)
                throw new InvalidDataException("Metadata nonnegative integer required: " + key);
            return result;
        }
        public static string Quote(string value)
        {
            var text = new StringBuilder("\"");
            foreach (char ch in value)
            {
                switch (ch)
                {
                    case '"': text.Append("\\\""); break;
                    case '\\': text.Append("\\\\"); break;
                    case '\n': text.Append("\\n"); break;
                    case '\r': text.Append("\\r"); break;
                    case '\t': text.Append("\\t"); break;
                    default:
                        if (ch < 32) text.Append("\\u" + ((int)ch).ToString("x4", CultureInfo.InvariantCulture));
                        else text.Append(ch);
                        break;
                }
            }
            return text.Append('"').ToString();
        }
        public static string Encode(object value)
        {
            if (value == null) return "null";
            if (value is string) return Quote((string)value);
            if (value is bool) return (bool)value ? "true" : "false";
            if (value is JsonNumber) return ((JsonNumber)value).Text;
            var map = value as IDictionary<string, object>;
            if (map != null)
            {
                var keys = new List<string>(map.Keys); keys.Sort(StringComparer.Ordinal);
                var text = new StringBuilder("{"); bool first = true;
                foreach (string key in keys)
                { if (!first) text.Append(','); first = false; text.Append(Quote(key)).Append(':').Append(Encode(map[key])); }
                return text.Append('}').ToString();
            }
            var list = value as IEnumerable;
            if (list != null)
            {
                var text = new StringBuilder("["); bool first = true;
                foreach (object item in list) { if (!first) text.Append(','); first = false; text.Append(Encode(item)); }
                return text.Append(']').ToString();
            }
            if (value is int || value is long) return Convert.ToString(value, CultureInfo.InvariantCulture);
            throw new InvalidDataException("Unsupported metadata JSON value");
        }
    }
}
