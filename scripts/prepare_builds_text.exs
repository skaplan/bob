defmodule Line do
  defstruct [:date, :time, :path, :ref, :sha, :otp]

  def from_line(line) do
    pattern = ~r|builds/elixir/(.*?)(-otp-.*)?\.zip|

    [date, time, _, path] = String.split(line)

    [ref, otp] =
      case Regex.run(pattern, path, capture: :all_but_first) do
        [ref] -> [ref, ""]
        [ref, otp] -> [ref, otp]
      end

    %Line{
      date: Date.from_iso8601!(date),
      time: Time.from_iso8601!(time),
      path: path,
      ref: ref,
      otp: otp
    }
  end

  def get_sha(line, repo_dir) do
    System.cmd("git", ["checkout", line.ref], cd: repo_dir)
    {sha, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: repo_dir)
    %{line | sha: String.trim(sha)}
  end

  def to_builds_txt(line) do
    [line.ref <> line.otp, line.sha, line.date, line.time] |> Enum.join(" ")
  end
end

input = "ls.txt"
output = "builds.txt"
repo = "https://github.com/elixir-lang/elixir.git"
repo_dir = "elixir"

if !File.dir?(repo_dir) do
  System.cmd("git", ["clone", repo, repo_dir])
end

content =
  File.stream!(input)
  |> Enum.map(&Line.from_line/1)
  |> Enum.map(&Line.get_sha(&1, repo_dir))
  |> Enum.map_join("\n", &Line.to_builds_txt/1)

File.write!(output, content)
{_, 0} = System.cmd("sort", ["-u", "-k1,1", "-o", output, output])
