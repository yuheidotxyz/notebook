package main

import (
	"crypto/md5"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/xml"
	"os"
)

func main() {
	var enex struct {
		Application string `xml:"application,attr"`
		Version     string `xml:"version,attr"`
		ExportDate  string `xml:"export-date,attr"`
		Notes       []struct {
			Title          string `xml:"title"`
			Created        string `xml:"created"`
			Updated        string `xml:"updated"`
			Content        string `xml:"content"`
			Body           string
			NoteAttributes struct {
				SubjectDate       string `xml:"subject-date"`
				Latitude          string `xml:"latitude"`
				Longitude         string `xml:"longitude"`
				Altitude          string `xml:"altitude"`
				Author            string `xml:"author"`
				Source            string `xml:"source"`
				SourceUrl         string `xml:"source-url"`
				SourceApplication string `xml:"source-application"`
				ReminderOrder     string `xml:"reminder-order"`
				ReminderTime      string `xml:"reminder-time"`
				ReminderDoneTime  string `xml:"reminder-done-time"`
				PlaceName         string `xml:"place-name"`
				ContentClass      string `xml:"content-class"`
			} `xml:"note-attributes"`
			Tags  []string `xml:"tag"`
			Tasks []struct {
				Title                 string `xml:"title"`
				Created               string `xml:"created"`
				Updated               string `xml:"updated"`
				TaskStatus            string `xml:"taskStatus"`
				InNote                string `xml:"inNote"`
				TaskFlag              string `xml:"taskFlag"`
				SortWeight            string `xml:"sortWeight"`
				NoteLevelID           string `xml:"noteLevelID"`
				TaskGroupNoteLevelID  string `xml:"taskGroupNoteLevelID"`
				DueDate               string `xml:"dueDate"`
				DueDateUIOption       string `xml:"dueDateUIOption"`
				TimeZone              string `xml:"timeZone"`
				Recurrence            string `xml:"recurrence"`
				RepeatAfterCompletion string `xml:"repeatAfterCompletion"`
				StatusUpdated         string `xml:"statusUpdated"`
				Creator               string `xml:"creator"`
				LastEditor            string `xml:"lastEditor"`
				Reminder              []struct {
					Created              string `xml:"created"`
					Updated              string `xml:"updated"`
					NoteLevelID          string `xml:"noteLevelID"`
					ReminderDate         string `xml:"reminderDate"`
					ReminderDateUIOption string `xml:"reminderDateUIOption"`
					TimeZone             string `xml:"timeZone"`
					DueDateOffset        string `xml:"dueDateOffset"`
					ReminderStatus       string `xml:"reminderStatus"`
				} `xml:"reminder"`
			} `xml:"task"`
			Resources []struct {
				Data               string `xml:"data"`
				Hash               string
				Mime               string `xml:"mime"`
				Width              string `xml:"width"`
				Height             string `xml:"height"`
				Duration           string `xml:"duration"`
				Recognition        string `xml:"recognition"`
				AlternateData      string `xml:"alternate-data"`
				ResourceAttributes struct {
					SourceUrl   string `xml:"source-url"`
					TimeStamp   string `xml:"timestamp"`
					FileName    string `xml:"file-name"`
					Latitude    string `xml:"latitude"`
					Longitude   string `xml:"longitude"`
					Altitude    string `xml:"altitude"`
					CameraMake  string `xml:"camera-make"`
					CameraModel string `xml:"camera-model"`
					RecoType    string `xml:"reco-type"`
					Attachment  string `xml:"attachment"`
				} `xml:"resource-attributes"`
			} `xml:"resource"`
		} `xml:"note"`
	}
	data, _ := os.ReadFile(os.Args[1])
	xml.Unmarshal(data, &enex)

	for i, note := range enex.Notes {
		var body struct {
			Inner string `xml:",innerxml"`
		}
		xml.Unmarshal([]byte(note.Content), &body)
		enex.Notes[i].Body = body.Inner
		for j, resource := range note.Resources {
			bs, _ := base64.StdEncoding.DecodeString(resource.Data)
			x := md5.Sum(bs)
			enex.Notes[i].Resources[j].Hash = hex.EncodeToString([]byte(x[:]))
		}
	}
	out, _ := json.Marshal(enex)
	os.Stdout.Write(out)
}
