// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

#pragma once

#include <cstdint>
#include <string>

namespace benchmarks {

struct Config {
  std::string path{};
  std::string weights{"NONE"};

  std::uint32_t resolution{};
};

}  // namespace benchmarks
