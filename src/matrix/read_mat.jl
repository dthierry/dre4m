# Copyright David Thierry. 2022. All Rights Reserved.
# Node module: read_mat.jl
# This file is licensed under the MIT License.
# License text available at https://opensource.org/licenses/MIT

"""
    loadExcelFile(inputFile::String)

Reads the excel file and initializes the matrices.
"""
function loadExcelFile(inputFile::String)
  c = coef(inputFile)
  i = attr(inputFile)
  return c, i
end
