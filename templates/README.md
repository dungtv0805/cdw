# Template cho dynamic workflow

Thư mục này có ba loại:
- `workflows/`: **một file cho mỗi loại yêu cầu**.
- `agents/`: **một file cho mỗi vai trò**.
- `claude/`: mẫu slash command mà `dw init` cài vào project.

`staffing.json` gán **capability tag** cho từng agent template; phase gọi đúng chuyên gia qua `needs`/`mayNeed` (xem dưới).

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
| `debate` | `participants`, `minRounds`, `maxRounds`, `protocol?`, `protocolSettings?` | Tranh luận theo vòng. Dừng khi mọi người đều `consensus` và không còn bất đồng major/blocking. Bất đồng blocking còn lại thì chuyển thành câu hỏi cho người dùng. `protocol`: `rounds` (mặc định), `cross-examination` (mỗi người nêu claim kèm bằng chứng, người khác chất vấn trên thread của claim, claim đứng vững hoặc bị nhượng bộ; nhật ký nằm trong `reports` của kết quả), hoặc `grilling` (một người hỏi, những người khác trả lời từ vai trò của mình: vòng hỏi chỉ gọi người hỏi, người này phán các câu chưa chốt rồi hỏi tiếp các câu có tiền đề đã chốt; vòng trả lời gọi những người còn lại, mỗi người trả lời kèm bằng chứng rồi chất vấn câu trả lời của người khác. Câu trả lời của owner được chốt khi không còn challenge major/blocking có bằng chứng; câu bị challenge, owner nhượng bộ hoặc owner không trả lời thì người hỏi phán. `protocolSettings.questioner` chỉ định người hỏi (mặc định là participant đầu tiên), `protocolSettings.maxQuestions` giới hạn số câu hỏi mới mỗi vòng; cần ít nhất 2 participant và `maxRounds` ≥ 3; cây câu hỏi nằm trong `reports`, digest ghi từng quyết định kèm `decidedBy`) |
| `escalate` | `liaison?`, `timeoutMs`, `onTimeout` (`assume`/`stop`), `maxQuestions` | Gom câu hỏi blocking thành một lần `bus_ask` tới `main`. Liaison mặc định là thành viên built-in `Liaison` |
| `synthesize` | `owner`, `reviewers`, `maxRevisions`, `artifact {name, sections}`, `trace?` | Owner viết tài liệu (`bus_artifact`), reviewer duyệt. Nếu có issue major thì owner sửa. Tài liệu phải được lưu đúng tên `artifact.name`, vì các phase sau chỉ tìm `artifact:<name>` theo tên đó: nếu owner trả về tên khác, một bước kiểm tra tất định đưa việc này vào vòng review (kể cả khi phase không có reviewer), và tên vẫn sai sau lần sửa cuối thì thành open issue. Bị bỏ qua khi tài liệu đó đã được cung cấp bằng `dw prepare --artifact`. `trace {prefix, from?}`: tài liệu đánh số điểm (`<prefix>1`, `<prefix>2`, …), mỗi điểm trace về điểm của các phase trong `from`; một bước kiểm tra tất định đưa điểm thiếu trace vào vòng review. `from` có thể là một debate phase nếu protocol của nó sinh point: grilling sinh các câu hỏi của nó, nên record phải trace mỗi quyết định về câu hỏi nó chốt và defer (kèm lý do) mỗi câu nó không quyết định |
| `plan` | `owner`, `reviewers`, `maxRevisions`, `maxItems` (mặc định 12), `artifact {name, sections}`, `trace?` | Như `synthesize`, nhưng owner trả thêm **work item**: `id`, `title`, `goal`, `acceptance[]`, `dependsOn[]`, `assignee?`, `tracesTo[]` (khi có `trace`), `needs[]` (capability tags mà item cần). Runtime chuẩn hoá id, bỏ phụ thuộc không tồn tại, và cắt bớt item vượt `maxItems` (ghi thành open issue). Muốn plan trả `needs` cho mỗi item, ghi trong `instructions` của plan phase (ví dụ "For each item, list `needs` — the capability tags it requires (e.g. `security`, `performance`)") |
| `execute` | `items` (id của một phase `plan` đứng trước), `assignees`, `reviewers` (mặc định không có), `navigators` (pool để chọn navigator per item), `maxRevisions`, `parallel` (mặc định `false`), `reviewTiming` (`after` hoặc `alongside`) | Mỗi work item do một agent mới làm, và **agent đó được sửa file trong project**. Item chạy theo thứ tự của plan sau khi các item nó phụ thuộc đã xong. Item phụ thuộc vào item `blocked` hoặc `failed` thì bị `skipped`. Nếu có `reviewers`, mỗi item qua vòng review/sửa. `parallel: true` cho các item sẵn sàng chạy cùng lúc; chúng dùng chung một working tree. `reviewTiming: "alongside"` chạy navigator song song với implementer: navigator theo dõi commit, post critique, rồi review cuối cùng — verdict của navigator là round 1 của review loop. `navigators` là pool member id; mỗi item chọn navigator theo capability coverage (nhiều tag khớp `needs` của item nhất, tie-break bằng thứ tự id). Pool rỗng thì chạy `after` và log. Navigator calls mang `agentType: "dw-navigator"` (read-only) |
| `review` | `owner`, `reviewers` (ít nhất 1), `maxRevisions` (mặc định 2) | Reviewer review toàn bộ kết quả đã giao. Owner sửa (được sửa file) hoặc phản bác bằng bằng chứng trên thread `review:<phase>`. Lặp tới khi không còn issue major/blocking hoặc hết số vòng. Bị bỏ qua khi không có gì được giao |

Mọi phase đều có `id`, `title`, `goal`, `instructions[]` và `context`. Phase có thể khai báo `needs: [<tag>]` (agent mang tag đó được đưa vào phase lúc compile) và `mayNeed: [<tag>]` (chỉ bật khi chạy `dw prepare --needs <phase>=<tag>,...`; `/dw` chọn theo brief và cho xem trước người, lý do, chi phí ước tính).

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
| `workspace:<name>` | nội dung file `.claude/context/<name>.md` | đường dẫn file |
| `knowledge:<filter>` | các file trong `.claude/context/` khớp filter (`type=`, `status=`, `scope=`, `confidence=`, ví dụ `knowledge:type=decision`); mỗi thành viên chỉ thấy file `scope: shared` và `scope: role:<agent của mình>` | danh sách file để đọc khi cần |

Một key xuất hiện ở nhiều mức thì giữ mức gần nhất: L0 thắng L1, L1 thắng L2.

## Knowledge header fields

Các file `.claude/context/*.md` có front-matter YAML. Ngoài các trường bắt buộc (`type`, `source`, `confidence`, `scope`, `updated`), còn có:

| Header field | Ý nghĩa |
|--------------|---------|
| `checklist` | Danh sách id phân cách bằng dấu phẩy, mỗi id tương ứng với một mục đánh số trong body. Ví dụ: `checklist: no-casts, registry-not-branch, run-checks`. Id được đầy đủ hoá thành `<file-stem>/<id>` (ví dụ `implementation/no-casts`). Review loop liệt kê các item trong prompt của reviewer và kiểm tra coverage trong kết quả. `dw context audit` báo khi số id không khớp số mục đánh số |

## Workspace context (`workspace:<name>`)

Inject project-specific knowledge từ `.claude/context/<name>.md` vào prompt của agent.

**Cách dùng:**

```json
{
  "context": {
    "L1": ["workspace:conventions", "workspace:guides/testing"]
  }
}
```

**Resolution:**
- `workspace:conventions` → `.claude/context/conventions.md`
- `workspace:guides/testing` → `.claude/context/guides/testing.md`

**Behavior:**
- Nội dung file render nguyên văn, không có header bao bọc
- File không tồn tại → `(workspace:<name> not available yet)`
- Path traversal bị chặn: `workspace:../secrets` trả về fallback
- Validation (`dw validate`) cảnh báo để nhắc kiểm tra file tồn tại trong project đích

**Khi nào dùng:**
- Architecture decisions mà agent cần biết
- Coding conventions riêng của project
- Domain context và terminology
- Testing guidelines

**Partitioning test:** Nếu nội dung thay đổi khi code thay đổi → query nó (Phase 2: `codebase-scan:`). Nếu nội dung thay đổi khi con người quyết định → curate nó với `workspace:`.
