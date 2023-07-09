// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

#include <absl/strings/str_split.h>
#include <fmt/compile.h>
#include <fmt/format.h>

#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

[[nodiscard]] static std::vector<std::size_t> parse_header(std::string_view line) {
  if (!absl::StartsWith(line, "#columns: ")) {
    return {};
  }

  line = absl::StripPrefix(absl::StripPrefix(line, "#columns:"), " ");
  const std::vector<std::string_view> toks{absl::StrSplit(line, absl::ByAnyChar(" \t"))};

  std::vector<std::size_t> idx{};
  // https://github.com/4dn-dcic/pairix/blob/master/pairs_format_specification.md#tools-for-pairs-file
  for (std::string_view key :
       {"strand1", "chr1", "pos1", "frag1", "strand2", "chr2", "pos2", "frag2"}) {
    const auto match = std::find(toks.begin(), toks.end(), key);
    if (match != toks.end()) {
      idx.push_back(static_cast<std::size_t>(std::distance(toks.begin(), match)));
    } else if (!absl::StartsWith(key, "frag")) {
      throw std::runtime_error(
          fmt::format(FMT_STRING("invalid header: missing column \"{}\""), key));
    }
  }

  return idx;
}

void print_sorted_tokens(const std::vector<std::size_t>& header,
                         const std::vector<std::string_view>& toks) {
  const auto has_fragments = header.size() > 6;

  // https://github.com/aidenlab/juicer/wiki/Pre#short-format
  if (has_fragments) {
    fmt::print(FMT_COMPILE("{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\n"), int(toks[header[0]] == "+"),
               toks[header[1]], toks[header[2]], toks[header[3]], int(toks[header[4]] == "+"),
               toks[header[5]], toks[header[6]], toks[header[7]]);
  } else {
    fmt::print(FMT_COMPILE("{}\t{}\t{}\t0\t{}\t{}\t{}\t1\n"), int(toks[header[0]] == "+"),
               toks[header[1]], toks[header[2]], int(toks[header[3]] == "+"), toks[header[4]],
               toks[header[5]]);
  }
}

int main() noexcept {
  try {
    std::ios_base::sync_with_stdio(false);

    std::string line;
    std::size_t max_idx = 0;
    std::vector<std::size_t> header{};
    std::vector<std::string_view> toks{};
    for (std::size_t i = 0; std::getline(std::cin, line); ++i) {
      if (header.empty()) {
        header = parse_header(line);
        if (!header.empty()) {
          max_idx = *std::max_element(header.begin(), header.end());
        }
        continue;
      }

      if (line.empty() || line.front() == '#') {
        continue;
      }

      toks = absl::StrSplit(line, '\t');
      if (toks.size() < max_idx) {
        throw std::runtime_error(fmt::format(
            FMT_STRING("line {}: expected {} or more tokens, found {}"), i, max_idx, toks.size()));
      }
      print_sorted_tokens(header, toks);
    }
  } catch (const std::exception& e) {
    fmt::print(stderr, FMT_STRING("{}\n"), e.what());
    return 1;
  } catch (...) {
    fmt::print(stderr, FMT_STRING("caught an unhandled exception!\n"));
    return 1;
  }
}
