/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.mhr@gmail.com>
 *
 */

namespace Synapse
{
  [Flags]
  public enum QueryFlags
  {
    INCLUDE_REMOTE  = 1 << 0,

    APPLICATIONS    = 1 << 1,
    ACTIONS         = 1 << 2,
    AUDIO           = 1 << 3,
    VIDEO           = 1 << 4,
    DOCUMENTS       = 1 << 5,
    IMAGES          = 1 << 6,
    INTERNET        = 1 << 7,

    UNCATEGORIZED   = 1 << 15,

    ALL           = 0xFF | QueryFlags.UNCATEGORIZED,
    LOCAL_CONTENT = ALL ^ QueryFlags.INCLUDE_REMOTE
  }
  
  [Flags]
  public enum MatcherFlags
  {
    NO_REVERSED   = 1 << 0,
    NO_SUBSTRING  = 1 << 1,
    NO_PARTIAL    = 1 << 2,
    NO_FUZZY      = 1 << 3
  }

  public struct Query
  {
    string query_string;
    string query_string_folded;
    Cancellable cancellable;
    QueryFlags query_type;
    uint max_results;
    uint query_id;

    public Query (uint query_id,
                  string query,
                  QueryFlags flags = QueryFlags.LOCAL_CONTENT,
                  uint num_results = 96)
    {
      this.query_id = query_id;
      this.query_string = query;
      this.query_string_folded = query.casefold ();
      this.query_type = flags;
      this.max_results = num_results;
    }

    public bool is_cancelled ()
    {
      return cancellable.is_cancelled ();
    }

    public void check_cancellable () throws SearchError
    {
      if (cancellable.is_cancelled ())
      {
        throw new SearchError.SEARCH_CANCELLED ("Cancelled");
      }
    }
    
    // FIXME: turn into 0.0 - 1.0 floats
    public const int MATCH_SCORE_MAX = 100;
    
    public const int MATCH_EXACT = 100;
    public const int MATCH_PREFIX = 90;
    public const int MATCH_WORD_PREFIX = 85;
    public const int MATCH_MULTIPLE_WORDS = 80;
    public const int MATCH_MULTIPLE_WORDS_REVERSED = 78;
    public const int MATCH_SUBSTRING = 75;
    public const int MATCH_FIRST_LETTERS = 70;
    public const int MATCH_FUZZY = 50;
    
    public const int MATCH_PENALTY_SMALL = 5;
    public const int MATCH_PENALTY_MEDIUM = 10;
    public const int MATCH_PENALTY_LARGE = 20;

    public static Gee.List<Gee.Map.Entry<Regex, int>>
    get_matchers_for_query (string query,
                            MatcherFlags match_flags = 0,
                            RegexCompileFlags flags = GLib.RegexCompileFlags.OPTIMIZE)
    {
      /* create a couple of regexes and try to help with matching
       * match with these regular expressions (with descending score):
       * 1) ^query$
       * 2) ^query
       * 3) \bquery
       * 4) split to words and seach \bword1.+\bword2 (if there are 2+ words)
       * 5) query
       * 6) split to characters and search \bq.+\bu.+\be.+\br.+\by
       * 7) split to characters and search \bq.*u.*e.*r.*y
       *
       * The set of returned regular expressions depends on MatcherFlags.
       */

      var results = new Gee.HashMap<Regex, int> ();
      Regex re;

      try
      {
        re = new Regex ("^(%s)$".printf (Regex.escape_string (query)), flags);
        results[re] = MATCH_EXACT;
      }
      catch (RegexError err)
      {
      }

      try
      {
        re = new Regex ("^(%s)".printf (Regex.escape_string (query)), flags);
        results[re] = MATCH_PREFIX;
      }
      catch (RegexError err)
      {
      }

      try
      {
        re = new Regex ("\\b(%s)".printf (Regex.escape_string (query)), flags);
        results[re] = MATCH_WORD_PREFIX;
      }
      catch (RegexError err)
      {
      }

      // split to individual chars
      string[] individual_words = Regex.split_simple ("\\s+", query.strip ());
      if (individual_words.length >= 2)
      {
        string[] escaped_words = {};
        foreach (unowned string word in individual_words)
        {
          escaped_words += Regex.escape_string (word);
        }
        string pattern = "\\b(%s)".printf (string.joinv (").+\\b(",
                                                         escaped_words));

        try
        {
          re = new Regex (pattern, flags);
          results[re] = MATCH_MULTIPLE_WORDS;
        }
        catch (RegexError err)
        {
        }

        // FIXME: do something generic here
        if (!(MatcherFlags.NO_REVERSED in match_flags))
        {
          if (escaped_words.length == 2)
          {
            var reversed = "\\b(%s)".printf (string.join (").+\\b(",
                                                        escaped_words[1],
                                                        escaped_words[0],
                                                        null));
            try
            {
              re = new Regex (reversed, flags);
              results[re] = MATCH_MULTIPLE_WORDS_REVERSED;
            }
            catch (RegexError err)
            {
            }
          }
          else
          {
            // not too nice, but is quite fast to compute
            var orred = "\\b((?:%s))".printf (string.joinv (")|(?:", escaped_words));
            var any_order = "";
            for (int i=0; i<escaped_words.length; i++)
            {
              bool is_last = i == escaped_words.length - 1;
              any_order += orred;
              if (!is_last) any_order += ".+";
            }
            try
            {
              re = new Regex (any_order, flags);
              results[re] = MATCH_MULTIPLE_WORDS_REVERSED - 1;
            }
            catch (RegexError err)
            {
            }
          }
        }
      }
      
      if (!(MatcherFlags.NO_SUBSTRING in match_flags))
      {
        try
        {
          re = new Regex ("(%s)".printf (Regex.escape_string (query)), flags);
          results[re] = MATCH_SUBSTRING;
        }
        catch (RegexError err)
        {
        }
      }

      // split to individual chars
      string[] individual_chars = Regex.split_simple ("\\s*", query);
      string[] escaped_chars = {};
      foreach (unowned string word in individual_chars)
      {
        escaped_chars += Regex.escape_string (word);
      }

      if (!(MatcherFlags.NO_PARTIAL in match_flags) &&
          individual_chars.length <= 5)
      {
        string pattern = "\\b(%s)".printf (string.joinv (").+\\b(",
                                                         escaped_chars));
        try
        {
          re = new Regex (pattern, flags);
          results[re] = MATCH_FIRST_LETTERS;
        }
        catch (RegexError err)
        {
        }
      }

      if (!(MatcherFlags.NO_FUZZY in match_flags))
      {
        string pattern = "\\b(%s)".printf (string.joinv (").*(",
                                                         escaped_chars));
        try
        {
          re = new Regex (pattern, flags);
          results[re] = MATCH_FUZZY;
        }
        catch (RegexError err)
        {
        }
      }

      var sorted_results = new Gee.ArrayList<Gee.Map.Entry<Regex, int>> ();
      var entries = results.entries;
      // FIXME: why it doesn't work without this?
      sorted_results.set_data ("entries-ref", entries);
      sorted_results.add_all (entries);
      sorted_results.sort ((a, b) =>
      {
        unowned Gee.Map.Entry<Regex, int> e1 = (Gee.Map.Entry<Regex, int>) a;
        unowned Gee.Map.Entry<Regex, int> e2 = (Gee.Map.Entry<Regex, int>) b;
        return e2.value - e1.value;
      });

      return sorted_results;
    }
  }
}
