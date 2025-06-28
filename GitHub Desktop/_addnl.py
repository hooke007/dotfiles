
import os
import sys
import argparse

def insert_lines_to_files(directory, newline_type='system'):

	line1 = ""
	line2 = ""

	if newline_type == 'lf':
		nl = '\n'
	elif newline_type == 'crlf':
		nl = '\r\n'
	else:
		nl = os.linesep

	text_extensions = [
		'.txt', '.md',
	]

	processed_files = 0

	for filename in os.listdir(directory):
		filepath = os.path.join(directory, filename)

		if not os.path.isfile(filepath):
			continue
		if not any(filename.lower().endswith(ext) for ext in text_extensions):
			continue
		
		try:
			with open(filepath, 'r', encoding='utf-8') as f:
				original_content = f.read()
			new_content = f"{line1}{nl}{line2}{nl}{original_content}"
			with open(filepath, 'w', encoding='utf-8', newline='') as f:
				f.write(new_content)
			print(f"已处理: {filename} [换行符: {'LF' if nl == '\n' else 'CRLF'}]")
			processed_files += 1

		except UnicodeDecodeError:
			print(f"跳过非文本文件: {filename}")
		except Exception as e:
			print(f"处理 {filename} 时出错: {str(e)}")

	print(f"\n操作完成！共处理 {processed_files} 个文件")
	print(f"使用的换行符: {'LF (\\n)' if nl == '\n' else 'CRLF (\\r\\n)'}")

def parse_arguments():
	parser = argparse.ArgumentParser(description='在文本文件开头插入指定内容')
	parser.add_argument('directory', nargs='?', default=os.getcwd(),
						help='目标目录（默认为当前目录）')
	parser.add_argument('--newline', choices=['lf', 'crlf', 'system'], default='system',
						help='换行符类型: lf (\\n), crlf (\\r\\n), system (系统默认)')
	return parser.parse_args()

if __name__ == "__main__":
	args = parse_arguments()

	if not os.path.isdir(args.directory):
		print(f"错误: 目录不存在 - {args.directory}")
		sys.exit(1)

	print(f"正在处理目录: {args.directory}")
	insert_lines_to_files(args.directory, args.newline)

