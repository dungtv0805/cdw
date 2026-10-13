# Template cho dynamic workflow

Thư mục này có ba loại:
- `workflows/`: **một file cho mỗi loại yêu cầu**.
- `agents/`: **một file cho mỗi vai trò**.
- `claude/`: mẫu slash command mà `dw init` cài vào project.

Muốn thêm template riêng cho một project, đặt chúng vào `<project>/.claude/dw-templates/{agents,workflows}/`. Các template ở đó được nạp sau template của package và ghi đè template trùng `id`. Kiểm tra bằng `bin/dw validate`.

## Agent template — `agents/<id>.json`

| Trường | Ý nghĩa |
|--------|---------|
| `id`, `name`, `summary` | Định danh và mô tả vai trò một dòng |
| `perspective`, `mission` | Góc nhìn và trách nhiệm |
| `skills[]` | `{name, phases, how}`. `phases` là kind (`explore`, `debate`, `task`, `escalate`, `synthesize`, `plan`, `execute`, `review`), id của phase, hoặc `"all"`. `how` ghi cách dùng skill trong vai này |
| `workStyle[]` | Thói quen làm việc cụ thể |
| `rules[]` | Luật cứng |
| `escalateWhen[]` | Khi nào một câu hỏi thuộc về người dùng |
| `context` | `{L0, L1, L2}`, xem bảng context key bên dưới |
| `groups[]` | Nhóm để gửi `@group` |
| `agentType` | (tuỳ chọn) chạy thành viên này bằng một custom subagent của Claude Code |

## Workflow template — `workflows/<id>.json`

| Trường | Ý nghĩa |
|--------|---------|
| `id`, `name`, `description`, `whenToUse`, `requestTypes[]` | Định danh và cho biết loại yêu cầu nào hợp với template này |
| `team[]` | `{id, agent, name?, perspective?, mission?, extraRules?, extraSkills?, groups?, subscribe?, context?}`. `id` là bus id; `agent` trỏ tới agent template |
| `texts{}` | Đoạn text dùng làm context `text:<name>` |
| `context` | Context chung cho cả team |
| `phases[]` | Danh sách phase, xem bảng bên dưới |
| `escalation.triggers[]` | Những loại câu hỏi được phép hỏi người dùng |
| `bus` | `topics`, `gatherTimeoutMs`, `maxMessagesPerAgent`, `maxContentChars`, `mainTypes` |

Các loại phase:

| `kind` | Trường riêng | Hành vi |
|--------|--------------|---------|
| `explore` | `participants`, `broadcast` | Từng người tự lập position rồi gửi cho cả team |
| `task` | `participants` | Từng người làm phần việc của mình theo `instructions` và chia sẻ finding |
| `debate` | `participants`, `minRounds`, `maxRounds` | Tranh luận theo vòng. Dừng khi mọi người đều `consensus` và không còn bất đồng major/blocking. Bất đồng blocking còn lại thì chuyển thành câu hỏi cho người dùng |
| `escalate` | `liaison?`, `timeoutMs`, `onTimeout` (`assume`/`stop`), `maxQuestions` | Gom câu hỏi blocking thành một lần `bus_ask` tới `main`. Liaison mặc định là thành viên built-in `Liaison` |
| `synthesize` | `owner`, `reviewers`, `maxRevisions`, `artifact {name, sections}` | Owner viết tài liệu (`bus_artifact`), reviewer duyệt. Nếu có issue major thì owner sửa. Bị bỏ qua khi tài liệu đó đã được cung cấp bằng `dw prepare --artifact` |
| `plan` | `owner`, `reviewers`, `maxRevisions`, `maxItems` (mặc định 12), `artifact {name, sections}` | Như `synthesize`, nhưng owner trả thêm **work item**: `id`, `title`, `goal`, `acceptance[]`, `dependsOn[]`, `assignee?`. Runtime chuẩn hoá id, bỏ phụ thuộc không tồn tại, và cắt bớt item vượt `maxItems` (ghi thành open issue) |
| `execute` | `items` (id của một phase `plan` đứng trước), `assignees`, `reviewers` (mặc định không có), `maxRevisions`, `parallel` (mặc định `false`) | Mỗi work item do một agent mới làm, và **agent đó được sửa file trong project**. Item chạy theo thứ tự của plan sau khi các item nó phụ thuộc đã xong. Item phụ thuộc vào item `blocked` hoặc `failed` thì bị `skipped`. Nếu có `reviewers`, mỗi item qua vòng review/sửa. `parallel: true` cho các item sẵn sàng chạy cùng lúc; chúng dùng chung một working tree |
| `review` | `owner`, `reviewers` (ít nhất 1), `maxRevisions` (mặc định 2) | Reviewer review toàn bộ kết quả đã giao. Owner sửa (được sửa file) hoặc phản bác bằng bằng chứng trên thread `review:<phase>`. Lặp tới khi không còn issue major/blocking hoặc hết số vòng. Bị bỏ qua khi không có gì được giao |

Mọi phase đều có `id`, `title`, `goal`, `instructions[]` và `context`.

Chỉ bước làm việc và bước sửa của `execute`/`review` được sửa file trong project; mọi bước khác được dặn chỉ đọc. Cách sửa project (git, test, commit) là quy ước của từng domain. Vì vậy hãy viết nó trong `texts` của template, ví dụ `workspace-rules` trong `feature-delivery.json`, chứ không đưa vào runtime.

Context key:

| Key | L0/L1 (đặt sẵn trong prompt) | L2 (chỉ liệt kê, lấy khi cần) |
|-----|-------------------------------|-------------------------------|
| `brief`, `team` | luôn có | luôn có |
| `decisions` | danh sách quyết định của người dùng | số lượng và chỗ để đọc |
| `text:<name>` | toàn văn | trích ngắn |
| `file:<path>` | bảo agent đọc file trước | đường dẫn |
| `artifact:<name>` | lệnh `bus_artifact get` cần chạy trước; chỉ hiện khi artifact đã có (do phase trước viết hoặc được cung cấp) | lệnh lấy |
| `phase:<id>` | tóm tắt kết quả của phase đó | tóm tắt ngắn |

Một key xuất hiện ở nhiều mức thì giữ mức gần nhất: L0 thắng L1, L1 thắng L2.
