# Make sure v is executable.
if ! command -v v; then
	echo "v not found"
	exit 1
fi

examples_dir=$(dirname $(realpath "$0"))
for path in $(find "$examples_dir" -wholename "*/main.v"); do
	# Add opencl define flag to opencl examples.
	define=""
	[[ "$path" =~ .*"opencl".* && ! "$VFLAGS" =~ .*"-d dlopencl".* ]] && define="-d dlopencl"

	cmd="v -o "$path.o" "$VFLAGS" "$define" "$path""
	echo "$cmd"
	eval "$cmd"
	[[ "$?" != "0" ]] && exit 1

	# Cleanup.
	rm -f "${file}.o"
done
